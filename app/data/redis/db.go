package redis

import (
	"fmt"
	"net/url"
	"os"

	"github.com/go-redis/redis/v8"
)

func New(url *url.URL, cluster bool, masterName string) (redis.UniversalClient, error) {
	opts, err := newFromString(url.String())
	if err != nil {
		return nil, err
	}

	if cluster {
		return redis.NewClusterClient(opts.Cluster()), nil
	} else if masterName != "" {
		fv := opts.Failover()
		fv.MasterName = masterName
		return redis.NewFailoverClient(fv), nil
	}

	return redis.NewUniversalClient(opts), nil
}

// TODO: move to _test
func TestDB() (redis.UniversalClient, error) {
	str, ok := os.LookupEnv("TEST_REDIS_URL")
	if !ok {
		return nil, fmt.Errorf("set TEST_REDIS_URL for redis tests")
	}

	opts, err := newFromString(str)
	if err != nil {
		return nil, err
	}

	if masterName, ok := os.LookupEnv("REDIS_MASTER_NAME"); ok {
		fv := opts.Failover()
		fv.MasterName = masterName
		return redis.NewFailoverClient(fv), nil
	}

	if _, ok = os.LookupEnv("REDIS_CLUSTER"); ok {
		return redis.NewClusterClient(opts.Cluster()), nil
	}

	return redis.NewUniversalClient(opts), nil
}

func newFromString(url string) (*redis.UniversalOptions, error) {
	cfg, err := redis.ParseURL(url)
	if err != nil {
		return nil, err
	}

	opts := &redis.UniversalOptions{
		Addrs:    []string{cfg.Addr},
		DB:       cfg.DB,
		Username: cfg.Username,
		Password: cfg.Password,
	}

	if cfg.TLSConfig != nil {
		opts.TLSConfig = cfg.TLSConfig
	}

	return opts, nil
}
