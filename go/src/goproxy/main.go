package main

import (
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/Sirupsen/logrus"
	"github.com/drone/drone/client"
	"github.com/drone/drone/model"
	"github.com/samalba/dockerclient"
)

// goproxy main purpose is to be a daemon connecting the docker daemon
// (remote API) and the custom Minecraft server (cubrite using lua scripts).
// But the cuberite lua scripts also execute goproxy as a short lived process
// to send requests to the goproxy daemon. If the program is executed without
// additional arguments it is the daemon "mode".
//
// As a daemon, goproxy listens for events from the docker daemon and send
// them to the cuberite server. It also listen for requests from the
// cuberite server, convert them into docker daemon remote API calls and send
// them to the docker daemon.

const (
	// droneDaemonURL defines the URL of drone daemon.
	droneDaemonURL = "http://118.193.185.191"
	// droneRepoName defines the name of a repo.
	droneRepoName = "hello-ci"
	// droneOwner defines the owner of the given repo defined in droneRepoName.
	droneOwner = "gaocegege"
)

var (
	droneClient client.Client
	// instance of DockerClient allowing for making calls to the docker daemon
	// remote API
	dockerClient *dockerclient.DockerClient
	// version of the docker daemon which is exposing the remote API
	dockerDaemonVersion string
)

// type CPUStats struct {
// 	TotalUsage  uint64
// 	SystemUsage uint64
// }

// // previousCPUStats is a map containing the previous CPU stats we got from the
// // docker daemon through the docker remote API
// var previousCPUStats map[string]*CPUStats = make(map[string]*CPUStats)

func main() {
	// Set the debug level.
	logrus.SetLevel(logrus.DebugLevel)

	// goproxy is executed as a short lived process to send a request to the
	// goproxy daemon process
	if len(os.Args) > 1 {
		// If there's an argument
		// It will be considered as a path for an HTTP GET request
		// That's a way to communicate with goproxy daemon
		if len(os.Args) == 2 {
			reqPath := "http://127.0.0.1:8000/" + os.Args[1]
			resp, err := http.Get(reqPath)
			if err != nil {
				logrus.Println("Error on request:", reqPath, "ERROR:", err.Error())
			} else {
				logrus.Println("Request sent", reqPath, "StatusCode:", resp.StatusCode)
			}
		}
		return
	}

	// init drone client object
	var err error
	droneClient = client.NewClient(droneDaemonURL)
	dockerClient, err = dockerclient.NewDockerClient("unix:///var/run/docker.sock", nil)
	if err != nil {
		logrus.Fatal(err.Error())
	}
	// start monitoring docker events
	go func() {
		var formerBuilds, builds []*model.Build
		var err error
		tick := time.NewTimer(5 * time.Second).C
		formerBuilds, err = droneClient.BuildList(droneOwner, droneRepoName)
		if err != nil {
			logrus.Error("Err emitted when getting builds from drone", err)
		}
		for {
			select {
			case <-tick:
				builds, err = droneClient.BuildList(droneOwner, droneRepoName)
				if err != nil {
					logrus.Error("Err emitted when getting builds from drone", err)
				}

				// Check whether the builds is more than formerBuilds.
				if len(builds) > len(formerBuilds) {
					for i := len(formerBuilds); i < len(builds); i++ {
						// TODO: enclose the code.
						data := url.Values{
							"action":  {"startBuild"},
							"id":      {string(builds[i].ID)},
							"name":    {string(builds[i].Number)},
							"running": {builds[i].Status},
						}
						CuberiteServerRequest(data)
					}
				}

				logrus.Println("Tick Over.")
				// Reset the tick.
				tick = time.NewTimer(5 * time.Second).C
			}
		}
	}()

	// start a http server and listen on local port 8000
	go func() {
		http.HandleFunc("/builds", listBuilds)
		http.HandleFunc("/exec", execCmd)
		http.ListenAndServe(":8000", nil)
	}()

	logrus.Println("Starting the goproxy server.")

	// wait for interruption
	<-make(chan int)
}

// eventCallback receives and handles the docker events
// func eventCallback(event *dockerclient.Event, ec chan error, args ...interface{}) {
// 	logrus.Debugln("--\n%+v", *event)

// 	id := event.ID

// 	switch event.Status {
// 	case "create":
// 		logrus.Debugln("create event")

// 		repo, tag := splitRepoAndTag(event.From)
// 		containerName := "<name>"
// 		containerInfo, err := dockerClient.InspectContainer(id)
// 		if err != nil {
// 			logrus.Print("InspectContainer error:", err.Error())
// 		} else {
// 			containerName = containerInfo.Name
// 		}

// 		data := url.Values{
// 			"action":    {"createContainer"},
// 			"id":        {id},
// 			"name":      {containerName},
// 			"imageRepo": {repo},
// 			"imageTag":  {tag}}

// 		CuberiteServerRequest(data)

// 	case "start":
// 		logrus.Debugln("start event")

// 		repo, tag := splitRepoAndTag(event.From)
// 		containerName := "<name>"
// 		containerInfo, err := dockerClient.InspectContainer(id)
// 		if err != nil {
// 			logrus.Print("InspectContainer error:", err.Error())
// 		} else {
// 			containerName = containerInfo.Name
// 		}

// 		data := url.Values{
// 			"action":    {"startContainer"},
// 			"id":        {id},
// 			"name":      {containerName},
// 			"imageRepo": {repo},
// 			"imageTag":  {tag}}

// 		// Monitor stats
// 		dockerClient.StartMonitorStats(id, statCallback, nil)
// 		CuberiteServerRequest(data)

// 	case "stop":
// 		// die event is enough
// 		// http://docs.docker.com/reference/api/docker_remote_api/#docker-events

// 	case "restart":
// 		// start event is enough
// 		// http://docs.docker.com/reference/api/docker_remote_api/#docker-events

// 	case "kill":
// 		// die event is enough
// 		// http://docs.docker.com/reference/api/docker_remote_api/#docker-events

// 	case "die":
// 		logrus.Debugln("die event")

// 		// same as stop event
// 		repo, tag := splitRepoAndTag(event.From)
// 		containerName := "<name>"
// 		containerInfo, err := dockerClient.InspectContainer(id)
// 		if err != nil {
// 			logrus.Print("InspectContainer error:", err.Error())
// 		} else {
// 			containerName = containerInfo.Name
// 		}

// 		data := url.Values{
// 			"action":    {"stopContainer"},
// 			"id":        {id},
// 			"name":      {containerName},
// 			"imageRepo": {repo},
// 			"imageTag":  {tag}}

// 		CuberiteServerRequest(data)

// 	case "destroy":
// 		logrus.Debugln("destroy event")

// 		data := url.Values{
// 			"action": {"destroyContainer"},
// 			"id":     {id},
// 		}

// 		CuberiteServerRequest(data)
// 	}
// }

// statCallback receives the stats (cpu & ram) from containers and send them to
// the cuberite server
// func statCallback(id string, stat *dockerclient.Stats, ec chan error, args ...interface{}) {

// 	// logrus.Debugln("STATS", id, stat)
// 	// logrus.Debugln("---")
// 	// logrus.Debugln("cpu :", float64(stat.CpuStats.CpuUsage.TotalUsage)/float64(stat.CpuStats.SystemUsage))
// 	// logrus.Debugln("ram :", stat.MemoryStats.Usage)

// 	memPercent := float64(stat.MemoryStats.Usage) / float64(stat.MemoryStats.Limit) * 100.0
// 	var cpuPercent float64 = 0.0
// 	if preCPUStats, exists := previousCPUStats[id]; exists {
// 		cpuPercent = calculateCPUPercent(preCPUStats, &stat.CpuStats)
// 	}

// 	previousCPUStats[id] = &CPUStats{TotalUsage: stat.CpuStats.CpuUsage.TotalUsage, SystemUsage: stat.CpuStats.SystemUsage}

// 	data := url.Values{
// 		"action": {"stats"},
// 		"id":     {id},
// 		"cpu":    {strconv.FormatFloat(cpuPercent, 'f', 2, 64) + "%"},
// 		"ram":    {strconv.FormatFloat(memPercent, 'f', 2, 64) + "%"}}

// 	CuberiteServerRequest(data)
// }

// execCmd handles http requests received for the path "/exec"
func execCmd(w http.ResponseWriter, r *http.Request) {

	io.WriteString(w, "OK")

	go func() {
		cmd := r.URL.Query().Get("cmd")
		cmd, _ = url.QueryUnescape(cmd)
		arr := strings.Split(cmd, " ")
		if len(arr) > 0 {

			if arr[0] == "docker" {
				arr[0] = "docker-" + dockerDaemonVersion
			}

			cmd := exec.Command(arr[0], arr[1:]...)
			// Stdout buffer
			// cmdOutput := &bytes.Buffer{}
			// Attach buffer to command
			// cmd.Stdout = cmdOutput
			// Execute command
			// printCommand(cmd)
			err := cmd.Run() // will wait for command to return
			if err != nil {
				logrus.Println("Error:", err.Error())
			}
		}
	}()
}

// listBuilds handles and reply to http requests having the path "/builds"
func listBuilds(w http.ResponseWriter, r *http.Request) {
	// answer right away to avoid dead locks in LUA
	io.WriteString(w, "OK")
	go func() {
		builds, err := droneClient.BuildList(droneOwner, droneRepoName)
		if err != nil {
			logrus.Println(err.Error())
			return
		}

		logrus.Debug("Getting builds from drone: %v", builds)
		for _, build := range builds {
			data := url.Values{
				"action":  {"buildsInfo"},
				"id":      {string(build.ID)},
				"name":    {string(build.Number)},
				"running": {build.Status},
			}
			logrus.Debug("Sending %s to mc server.", data)
			CuberiteServerRequest(data)
		}
	}()
}

// Utility functions

// func calculateCPUPercent(previousCPUStats *CPUStats, newCPUStats *dockerclient.CpuStats) float64 {
// 	var (
// 		cpuPercent = 0.0
// 		// calculate the change for the cpu usage of the container in between readings
// 		cpuDelta = float64(newCPUStats.CpuUsage.TotalUsage - previousCPUStats.TotalUsage)
// 		// calculate the change for the entire system between readings
// 		systemDelta = float64(newCPUStats.SystemUsage - previousCPUStats.SystemUsage)
// 	)

// 	if systemDelta > 0.0 && cpuDelta > 0.0 {
// 		cpuPercent = (cpuDelta / systemDelta) * float64(len(newCPUStats.CpuUsage.PercpuUsage)) * 100.0
// 	}
// 	return cpuPercent
// }

// func splitRepoAndTag(repoTag string) (string, string) {

// 	repo := ""
// 	tag := ""

// 	repoAndTag := strings.Split(repoTag, ":")

// 	if len(repoAndTag) > 0 {
// 		repo = repoAndTag[0]
// 	}

// 	if len(repoAndTag) > 1 {
// 		tag = repoAndTag[1]
// 	}

// 	return repo, tag
// }

// CuberiteServerRequest send a POST request that will be handled
// by our Cuberite Docker plugin.
func CuberiteServerRequest(data url.Values) {
	client := &http.Client{}
	req, _ := http.NewRequest("POST", "http://127.0.0.1:8080/webadmin/Drone/Drone", strings.NewReader(data.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.SetBasicAuth("admin", "admin")
	_, err := client.Do(req)
	if err != nil {
		logrus.Errorln("Error when send POST request to cuberite server.", err)
	}
}
