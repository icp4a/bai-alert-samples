# Processing IBM Business Automation Insights alerts

IBM Business Automation Insights allows you to setup and visualize alerts on period KPI charts. IBM Business Automation Insights 23.0.2 brings the additional capacity to send alerts to a Kafka topic created as part of a Business Automation Insights deployment.<br/><br/>
This repository provides two samples that illustrate how alerts that have been posted to the Kafka topic can be read and forwarded to external recipients:
* The first sample illustrates how to forward events to a **Slack channel**.
* The second sample illustrates how to forward events to an **email address**.<br/>

To run the samples, you need to deploy them in the OpenShift cluster that hosts the IBM Business Automation Insights deployment. They can be deployed separately. The samples are based on the following items:
* Instructions to build a container image used specifically for the samples and containing the required tools. The same image is used for both samples.
* Kubernetes resources that allow you to deploy a Kubernetes pod running the sample container image. Sample execution code is provided in a bash shell script embedded in a Kubernetes config map.

**Important**: These samples are provided as examples for illustrative purpose and are not intended or supported for use in a production system. They are designed to work with IBM Business Automation Insights 23.0.2 or later.

## Prerequisites
### Tools 
To deploy the samples, you need the following tools:
* `bash` on Linux. `zsh` can be used on MacOS
* `oc` OpenShift command-line interface for deploying Kubernetes resources
* `podman` for building and pushing the sample image

**Note:** These instructions have been tested on RedHat Linux OS (8, 9) and MacOS (Ventura, Sonoma).

### Slack sample
The slack sample posts messages to Slack using Incoming Webhooks. Information on how to configure Incoming Webhooks for Slack can be found at https://api.slack.com/messaging/webhooks.

### Email sample
The email sample sends mails using an SMTP mail server. The sample has been tested with smtp.gmail.com.

## Deploying the alert notification samples

### Create a route to expose the OpenShift image registry
1. Log in to the namespace where the IBM Cloud Pak for Business Automation platform is deployed.

1. Run the following command to create a route exposing the OpenShift image registry. This route will be used to log in to the registry and push the sample image built in the following steps. 
```
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
export APISERVER=`oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}'`
```

### Build and push the sample image
1. Clone or download the GitHub project from https://github.com/icp4a/bai-alert-samples, and then decompress it. Ensure your command line current directory is bai-alert-samples. <br />
1. Set CP4BA_NAMESPACE environment variable to the name of the OpenShift namespace where IBM Cloud Pak for Business Automation has been deployed.
    ```
    export CP4BA_NAMESPACE=<cp4ba_namespace>
    ```
1. Run the following commands to build the image and push it to the OpenShift image registry:<br /><br/>
    ```
    export BAI_SAMPLE_IMAGE_PATH=${APISERVER}/${CP4BA_NAMESPACE}/bai-alert-sample:latest
    podman build --no-cache --platform linux/amd64  -t ${BAI_SAMPLE_IMAGE_PATH} .
    podman login -u kubeadmin -p $(oc whoami -t) --tls-verify=false $APISERVER
    podman push ${BAI_SAMPLE_IMAGE_PATH} --tls-verify=false
    ```
    **Note:** The sample container image is based on OpenJDK11 Red Hat Universal Base Image. It includes installation of additional tools required for sample execution (`jq`, Apache Kafka, `oc` OpenShift command-line). The instructions are provided for OpenShift Linux x86_64 Platform.

    **Note:** On MacOS, podman requires a virtual machine. It can be initialized and started using the following commands:<br/>
    ```
    podman machine init
    podman machine start
    ```
1. You can remove the route using following command:
    ```
    oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":false}}' --type=merge
    ```
### Deploy Kubernetes sample resources

Follow either "Deploy Kubernetes slack sample resources" or "Deploy Kubernetes email sample resources"

#### Deploy Kubernetes slack sample resources

1. In `./resources/bai-alert-sample-deployment.yml` file, update image path to set <cp4ba_namespace> value.  
    ```
    image: image-registry.openshift-image-registry.svc:5000/<cp4ba_namespace>/bai-alert-sample:latest
    ```

2. Set SLACK_WEBHOOK environment variable:
    ```
    export SLACK_WEBHOOK=<slack_webhook>
    ```

3. Log in to the namespace where the IBM Cloud Pak for Business Automation platform is deployed.

4. Create Kubernetes secret storing Slack webhook.
    ```
    oc create secret generic bai-alert-sample-secret -n ${CP4BA_NAMESPACE} --from-literal=slack-webhook=${SLACK_WEBHOOK}
    ```

5. Deploy Kubernetes sample resources:
    ```
    oc project ${CP4BA_NAMESPACE}
    oc apply -f ./resources/bai-slack-sample/bai-alert-sample-configmap.yml      
    oc apply -f ./resources/bai-slack-sample/bai-alert-sample-deployment.yml
    oc apply -f ./resources/bai-slack-sample/bai-alert-sample-service-account.yml
    ```

6. Check deployment status
    ```
    oc get pods | grep sample
    ```
The `bai-alert-sample` pod should be in Running status.

#### Deploy Kubernetes email sample resources

1. In `./resources/bai-alert-sample-deployment.yml` file, update image path to set <cp4ba_namespace> value.  
    ```
    image: image-registry.openshift-image-registry.svc:5000/<cp4ba_namespace>/bai-alert-sample:latest
    ```

2. Set environment variables:
    ```
    export EMAIL_PROTOCOL=<email_protocol> # example: smtp
    export EMAIL_SERVER_HOST=<email_server_host> # example: smtp.gmail.com
    export EMAIL_SERVER_PORT=<email_server_port> # example: 587
    export EMAIL_FROM=<email_from>
    export EMAIL_TO=<email_to>
    export EMAIL_USERNAME=<email_username>
    export EMAIL_PASSWORD=<email_password>
    ```

3. Log in to the namespace where the IBM Cloud Pak for Business Automation platform is deployed.

4. Create Kubernetes secret storing environment variables.
    ```
    oc create secret generic bai-alert-sample-secret -n ${CP4BA_NAMESPACE} --from-literal=email_protocol=${EMAIL_PROTOCOL} --from-literal=email_server_host=${EMAIL_SERVER_HOST} --from-literal=email_server_port=${EMAIL_SERVER_PORT} --from-literal=email_from=${EMAIL_FROM} --from-literal=email_to=${EMAIL_TO} --from-literal=email_username=${EMAIL_USERNAME} --from-literal=email_password=${EMAIL_PASSWORD}
    ```

5. Deploy Kubernetes sample resources:
    ```
    oc project ${CP4BA_NAMESPACE}
    oc apply -f ./resources/bai-email-sample/bai-alert-sample-configmap.yml      
    oc apply -f ./resources/bai-email-sample/bai-alert-sample-deployment.yml
    oc apply -f ./resources/bai-email-sample/bai-alert-sample-service-account.yml
    ```

6. Check deployment status
    ```
    oc get pods | grep sample
    ```
The `bai-alert-sample` pod should be in Running status.


### Create an alert and view the notification
1. Login to Business Performance Center and define an alert.
2. Check that the message sent to the Slack channel or Email account contains the following data:
    ```
    An alert has been triggered in dashboard <dashboard name>:
     . Trigger: <alert trigger message>
     . Threshold value: <alert threshold value>
     . Message: <alert message>
     . Priority: <alert priority>
     . Value: <value of data point that triggered the alert>
     . Timestamp: <timestamp of data point that triggered the alert>
     . Chart name: <chart name>
     . Monitoring source: <chart monitoring source name>
     . Dashboard owner: <dashboard owner id>
     . Dashboard type: <dashboard type>
    ```

NB: Only Kafka events submitted to the Kafka topic when the sample is running are read from the Kafka topic.
