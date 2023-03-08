# AWS Cloud Gaming
This repo will automate the creation and connection to an AWS EC2 spot instance to be used for cloud gaming.

## Prerequisites

* Running on an Ubuntu system
* [AWS CLI (v2)](https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip) is installed
* [Node.js](https://linuxize.com/post/how-to-install-node-js-on-ubuntu-22-04/) and NPM are installed
* You have sudo permissions on your current system

## Configuration

### Environment Variables

| Name                       | Description                                                                                                                                                                                                                                                                  | Example                                  |
|----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|
| `AWS_CLOUD_GAMING_PROFILE` | The AWS profile to use corresponding to a profile in your AWS config (usually ~/.aws/config).<br/><br/> Defaults to `personal`<br/><br/> This profile should have permissions to create the appropriate resources in AWS, including CloudFormation stacks, and EC2 instances | `AWS_CLOUD_GAMING_PROFILE=uber-sandbox`  |
| `AWS_CLOUD_GAMING_SSH_KEY` | The name of some key pair that exists in AWS and that you have locally in your `~/.ssh` directory                                                                                                                                                                            | `AWS_CLOUD_GAMING_SSH_KEY=team-building` |

### CDK Variables
Modify the following properties in the [cloud-gaming-on-ec2](cdk/bin/cloud-gaming-on-ec2.ts) stack:

| Parameter Name             | Description                                                         |
|----------------------------|---------------------------------------------------------------------|
| `ACCOUNT_ID`               | The AWS account ID you want to use                                  |
| `REGION`                   | The AWS region in which you want the resources created              |
| `VPC_ID`                   | The ID of the VPC you wish to deploy the instance into              |
| `SUBNET_ID`                | The ID of a public subnet that you want your instance deployed into |
| `SUBNET_AVAILABILITY_ZONE` | The availability zone of the subnet you provided                    |

## Running the application
To run the application, simply run 
```shell
./cloud-gaming.sh
```
from the root directory and follow all instructions/menu choices and the script will take care of everything else!

## Debugging
The scripts output logs to `/tmp/cloud-gaming.log` for easy debugging and auditing.

Note that CDK specific logs are output for each CDK task (`synth`, `bootstrap`, `deploy`) in their own log files to make debugging the CDK easier:

* `synth` outputs logs to `/tmp/cdk-synth.log`
* `bootstrap` outputs logs to `/tmp/cdk-bootstrap.log`
* `deploy` outputs logs to `/tmp/cdk-deploy.log`

## Customizing the EC2 Instance

### Change the Instance type

To change the instance type, simply create a new stack that subclasses the [base.ts](cdk/lib/base.ts), and override the `getUserData()` and `getInstanceType()`
methods to change the type, and customize the user data for the instance. Just make sure to add the `new` call to this stack in [cloud-gaming-on-ec2.ts](cdk/bin/cloud-gaming-on-ec2.ts)

### Log into instance desktop

You can log into the desktop of the instance via the `Manage Personal Instance` menu in the `cloud-gaming.sh` script.

### Managing instance state

All personal instance management can be achieved via the `Manage Personal Instance` menu in the `cloud-gaming.sh` script.
This includes

* Checking the state of the instance (`started`, `stopped`, `terminated`, etc.)
* Start the instance
* Stop the instance

## Managing the Stream

There are two types of streams this project enables: Personal and Shared

### Personal Streams

A personal stream is a Steam Link stream to your personal EC2 instance. This is ideal for online multiplayer games where players all play on their own machines.

You can start a stream to your personal instance via the `Stream Settings` menu in the `cloud-gaming.sh` script. This will prompt to start your personal instance if it's not already started.

### Shared Streams

A shared stream is a Steam Link stream to an instance that multiple people are connecting to at once. This is ideal for couch co-op games like Super Smash Bros, Mario Kart, etc.
where everyone needs to be on the same machine.

You can either be a host or a player in a shared stream.

Hosts host the shared stream on their EC2 instance, and players are the other players connecting to that same instance.

The `Stream Settings` menu in the `cloud-gaming.sh` script will guide you through the setup of either the host or player stream for a shared stream.

Note: A Shared stream will not overwrite your settings to connect to your personal instance. You'll just have to change back to your personal instance in Steam Link via the Gear icon -> Computers menu.

## Built With
* [Bash](https://www.gnu.org/software/bash/) - Shell that all the scripts are written in
* [Node.js](https://nodejs.org/en/) - JS runtime for CDK
* [TypeScript](https://www.typescriptlang.org/) - CDK stacks and constructs are written in TS
* [AWS CDK](https://aws.amazon.com/cdk/) - AWS Cloud Development Kit is IaC using familiar programming languages. It's used to define the EC2 instance
* [AWS CLI](https://aws.amazon.com/cli/) - Used to manage the EC2 instance; e.g. get credentials for instance, start/stop/restart instance, check instance status, etc.
* [Whiptail](https://linux.die.net/man/1/whiptail) - Used to create a TUI for the user
* [Dialog](https://linux.die.net/man/1/dialog) - Used to display tail boxes for long-running processes like CDK deploys
* [NICE DCV](https://aws.amazon.com/hpc/dcv/) - High-performance RDP for connecting to EC2 instance desktop
* [Xvfb](https://www.x.org/archive/X11R7.6/doc/man/man1/Xvfb.1.xhtml) - X Virtual FrameBuffer, used to open a connection to your instance via NICE DCV in the background. Necessary to allow SteamLink connections to your instance
* [Steam Link](https://store.steampowered.com/app/353380/Steam_Link/) - High quality, low latency stream from your machine to your EC2 instance that forwards all inputs, controllers or otherwise.
* [Flatpak](https://flatpak.org/) - Used to install Steam Link (Ubuntu only)
* [xdotool](https://manpages.ubuntu.com/manpages/trusty/man1/xdotool.1.html) - X11 automation tool to minimize the terminal
* [pulsemixer](https://github.com/GeorgeFilipkin/pulsemixer) - Used to mute NICE DCV running in Xvfb so there's no echoing of sound between Steam Link and NICE DCV
* [nc](http://netcat.sourceforge.net/) - Ping the EC2 instance on port 8443 to see when NICE DCV is running