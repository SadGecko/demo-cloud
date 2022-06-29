#!/bin/bash

docker build -t sadgecko/wp:last ./src
docker push sadgecko/wp:last