package utils

import (
	"os"

	"github.com/Sirupsen/logrus"
)

// GetStringEnvWithDefault get evironment value of 'name', and return provided
// default value if not found.
func GetStringEnvWithDefault(name, def string) string {
	var val string
	if val = os.Getenv(name); val == "" {
		logrus.Infof("Env variant %s not found, using default value: %s", name, def)
		return def
	}
	logrus.Infof("Env variant %s found, using env value: %s", name, val)
	return val
}
