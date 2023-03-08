/* tslint:disable:no-import-side-effect no-submodule-imports no-unused-expression */
import "source-map-support/register";
import { G4ADStack } from "../lib/g4ad";
import {App} from "aws-cdk-lib";
import {InstanceSize} from "aws-cdk-lib/aws-ec2";

const app = new App();

const NICE_DCV_DISPLAY_DRIVER_URL = "https://d1uj6qtbmh3dt5.cloudfront.net/Drivers/nice-dcv-virtual-display-x64-Release-34.msi";
const NICE_DCV_SERVER_URL = "https://d1uj6qtbmh3dt5.cloudfront.net/2021.0/Servers/nice-dcv-server-x64-Release-2021.0-10242.msi";
const VOLUME_SIZE_GIB = 150;
const OPEN_PORTS = [3389, 8443];
const ACCOUNT_ID = "PLACEHOLDER"
const REGION = "us-east-1"
const VPC_ID = 'PLACEHOLDER'
const SUBNET_ID = 'PLACEHOLDER'
const SUBNET_AVAILABILITY_ZONE = 'PLACEHOLDER'

const user = app.node.tryGetContext("user");
if (!user) {
    throw new Error("User is a required parameter. Specify it with `-c user=me`.");
}

const localIp = app.node.tryGetContext("localIp");
if (!localIp) {
    throw new Error("Local IP is a required parameter. Specify it with '-c localIp=XXX.XXX.XXX.XXX'.");
}

const sshKeyName = process.env.AWS_CLOUD_GAMING_SSH_KEY;
if (!sshKeyName) {
    throw new Error("SSH key name is a required parameter. Specify it by setting the environment variable 'AWS_CLOUD_GAMING_SSH_KEY'.");
}

new G4ADStack(app, `TeamBuildingCloudGaming-${user}`, {
    niceDCVDisplayDriverUrl: NICE_DCV_DISPLAY_DRIVER_URL,
    niceDCVServerUrl: NICE_DCV_SERVER_URL,
    instanceSize: InstanceSize.XLARGE4,
    sshKeyName,
    volumeSizeGiB: VOLUME_SIZE_GIB,
    openPorts: OPEN_PORTS,
    allowInboundCidr: `${localIp}/32`,
    env: {
        account: ACCOUNT_ID,
        region: REGION
    },
    tags: {
        "Application": "cloud-gaming"
    },
    user,
    vpcId: VPC_ID,
    subnetId: SUBNET_ID,
    subnetAvailabilityZone: SUBNET_AVAILABILITY_ZONE
});
