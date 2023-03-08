import { BaseConfig, BaseEc2Stack } from "./base";
import {App} from "aws-cdk-lib";
import {InstanceType, UserData} from "aws-cdk-lib/aws-ec2";

// tslint:disable-next-line:no-empty-interface
export interface G4ADConfig extends BaseConfig {

}

export class G4ADStack extends BaseEc2Stack {
    protected props: G4ADConfig;

    constructor(scope: App, id: string, props: G4ADConfig) {
        super(scope, id, props);
    }

    protected getUserdata() {
        const userData = UserData.forWindows();
        const { niceDCVDisplayDriverUrl, niceDCVServerUrl } = this.props;

        userData.addCommands(
            `$NiceDCVDisplayDrivers = "${niceDCVDisplayDriverUrl}"`,
            `$NiceDCVServer = "${niceDCVServerUrl}"`,
            '$SteamInstallation = "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"',
            '$MicrosoftEdgeInstallation = "https://go.microsoft.com/fwlink/?linkid=2108834&Channel=Stable&language=en"',
            `$InstallationFilesFolder = "$home\\Desktop\\InstallationFiles"`,
            `$Bucket = "ec2-amd-windows-drivers"`,
            `$KeyPrefix = "latest"`,
            `$Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1`,
            `foreach ($Object in $Objects) {
                $LocalFileName = $Object.Key
                if ($LocalFileName -ne '' -and $Object.Size -ne 0) {
                    $LocalFilePath = Join-Path $InstallationFilesFolder $LocalFileName
                    Copy-S3Object -BucketName $Bucket -Key $Object.Key -LocalFile $LocalFilePath -Region us-east-1
                    Expand-Archive $LocalFilePath -DestinationPath $InstallationFilesFolder\\1_AMD_driver
                }
            }`,
            'pnputil /add-driver $home\\Desktop\\InstallationFiles\\1_AMD_Driver\\210414a-365562C-Retail_End_User.2\\packages\\Drivers\\Display\\WT6A_INF/*.inf /install',
            'Invoke-WebRequest -Uri $NiceDCVServer -OutFile $InstallationFilesFolder\\2_NICEDCV-Server.msi',
            'Invoke-WebRequest -Uri $NiceDCVDisplayDrivers -OutFile $InstallationFilesFolder\\3_NICEDCV-DisplayDriver.msi',
            'Remove-Item $InstallationFilesFolder\\latest -Recurse',
            'Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString(\'https://community.chocolatey.org/install.ps1\'))',
            'choco feature enable -n=allowGlobalConfirmation',
            'choco install steam-rom-manager',
            'choco install steam-client --ignore-checksums',
            'choco install microsoft-edge',
            `Start-Process msiexec.exe -Wait -ArgumentList '/I C:\\Users\\Administrator\\Desktop\\InstallationFiles\\2_NICEDCV-Server.msi /QN /L* "C:\\msilog.log"'`,
            `Start-Process msiexec.exe -Wait -ArgumentList '/I C:\\Users\\Administrator\\Desktop\\InstallationFiles\\3_NICEDCV-DisplayDriver.msi /QN /L* "C:\\msilog.log"'`,
            `'' >> $InstallationFilesFolder\\OK`
        );

        return userData;
    }

    protected getInstanceType() {
        return new InstanceType(`g4ad.${this.props.instanceSize}`);
    }
}
