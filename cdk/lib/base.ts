/* tslint:disable:no-submodule-imports quotemark no-unused-expression */

import {
    BlockDeviceVolume,
    CfnLaunchTemplate,
    EbsDeviceVolumeType,
    Instance,
    InstanceSize,
    MachineImage,
    Peer,
    Port,
    SecurityGroup,
    Subnet, UserData,
    Vpc,
    WindowsVersion,
    InstanceType
} from "aws-cdk-lib/aws-ec2";
import {App, CfnOutput, Stack, StackProps} from "aws-cdk-lib";
import {ManagedPolicy, Role, ServicePrincipal} from "aws-cdk-lib/aws-iam";

export interface BaseConfig extends StackProps {
    readonly instanceSize: InstanceSize;
    readonly vpcId: string;
    readonly subnetId: string;
    readonly sshKeyName: string;
    readonly volumeSizeGiB: number;
    readonly niceDCVDisplayDriverUrl: string;
    readonly niceDCVServerUrl: string;
    readonly openPorts: number[];
    readonly allowInboundCidr: string;
    readonly user: String;
}

export abstract class BaseEc2Stack extends Stack {
    protected props: BaseConfig;

    constructor(scope: App, id: string, props: BaseConfig) {
        super(scope, id, props);
        this.props = props;
        const { vpcId, subnetId, sshKeyName, volumeSizeGiB, openPorts, allowInboundCidr, user } = props;
        const vpc = Vpc.fromLookup(this, "Vpc", { vpcId });

        const securityGroup = new SecurityGroup(this, `SecurityGroup-${user}`, {
            vpc,
            description: `Allow RDP, and NICE DCV access for ${user}`,
            securityGroupName: `InboundAccessFromRdpDcvFor${user}`
        });

        for (const port of openPorts) {
            securityGroup.connections.allowFrom(Peer.ipv4(allowInboundCidr), Port.tcp(port));
        }

        const role = new Role(this, `${id}S3Read-${user}`, {
            roleName: `${id}.GraphicsDriverS3Access-${user}`,
            assumedBy: new ServicePrincipal('ec2.amazonaws.com'),
            managedPolicies: [
                ManagedPolicy.fromAwsManagedPolicyName('AmazonS3ReadOnlyAccess')
            ],
        });

        const launchTemplate = new CfnLaunchTemplate(this, `TeamBuildingCloudGamingLaunchTemplate-${user}`, {
            launchTemplateData: {
                keyName: sshKeyName,
                instanceType: this.getInstanceType().toString(),
                networkInterfaces: [{
                    subnetId,
                    deviceIndex: 0,
                    description: "ENI",
                    groups: [securityGroup.securityGroupId]
                }],
                instanceMarketOptions: {
                    spotOptions: {
                        blockDurationMinutes: 120,
                        instanceInterruptionBehavior: "stop",
                    }
                }
            },
            launchTemplateName: `TeamBuildingCloudGamingInstanceLaunchTemplate-${user}/${this.getInstanceType().toString()}`,
        });

        const ec2Instance = new Instance(this, `EC2Instance-${user}`, {
            instanceType: this.getInstanceType(),
            vpc,
            securityGroup,
            vpcSubnets: vpc.selectSubnets({ subnets: [Subnet.fromSubnetAttributes(this, 'publicSubnet', {subnetId, availabilityZone: "us-east-1a"})] }),
            keyName: sshKeyName,
            userData: this.getUserdata(),
            machineImage: MachineImage.latestWindows(WindowsVersion.WINDOWS_SERVER_2019_ENGLISH_FULL_BASE),
            blockDevices: [
                {
                    deviceName: "/dev/sda1",
                    volume: BlockDeviceVolume.ebs(volumeSizeGiB, {
                        volumeType: EbsDeviceVolumeType.GP3,
                        encrypted: true
                    }),
                }
            ],
            role,
            instanceName: `TeamBuildingCloudGaming-${user}/${this.getInstanceType().toString()}`
        });

        new CfnOutput(this, `Public IP`, { value: ec2Instance.instancePublicIp });

        new CfnOutput(this, `Credentials`, { value: `https://${this.region}.console.aws.amazon.com/ec2/v2/home?region=${this.region}#ConnectToInstance:instanceId=${ec2Instance.instanceId}` });
        new CfnOutput(this, `InstanceId`, { value: ec2Instance.instanceId });
        new CfnOutput(this, `KeyName`, { value: sshKeyName });
        new CfnOutput(this, `LaunchTemplateId`, { value: launchTemplate.launchTemplateName! });
    }

    protected abstract getUserdata(): UserData;

    protected abstract getInstanceType(): InstanceType;
}
