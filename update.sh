#!/bin/bash

rm -v go.sum
hugo mod clean --all
hugo mod tidy
hugo mod get -u
