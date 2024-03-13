import requests
import schedule
import time
import boto3


class TBCHttpHealthChecker:
    primary_server_failed_health_check_count = 0
    primary_server_successful_health_check_count = 0
    primary_server_is_healthy = True

    def __init__(
            self,
            healthy_threshold_count: int,
            unhealthy_threshold_count: int,
            health_check_timeout_seconds: int,
            health_check_interval_seconds: int,
            primary_server_instance_id: str,
            failover_server_instance_id: str,
            eip_allocation_id: str,
            failover_server_security_group_id: str
    ) -> None:
        self.healthy_threshold_count = healthy_threshold_count
        self.unhealthy_threshold_count = unhealthy_threshold_count
        self.health_check_timeout_seconds = health_check_timeout_seconds
        self.health_check_interval_seconds = health_check_interval_seconds
        self.primary_server_instance_id = primary_server_instance_id
        self.failover_server_instance_id = failover_server_instance_id
        self.eip_allocation_id = eip_allocation_id
        self.failover_server_security_group_id = failover_server_security_group_id

    def health_check(self, server_ip):
        try:
            response = requests.get('http://' + server_ip, timeout=self.health_check_timeout_seconds)

            if response.status_code == 200:
                self.primary_server_successful_health_check_count += 1
                self.primary_server_failed_health_check_count = 0
            else:
                self.primary_server_failed_health_check_count += 1
                self.primary_server_successful_health_check_count = 0
        except requests.exceptions.Timeout:
            self.primary_server_failed_health_check_count += 1
            self.primary_server_successful_health_check_count = 0
        except requests.exceptions.RequestException as e:
            self.primary_server_failed_health_check_count += 1
            self.primary_server_successful_health_check_count = 0
            # print("An error occurred:", e)

    @staticmethod
    def get_ec2_ip_address(instance_id):
        ec2_client = boto3.client('ec2')

        response = ec2_client.describe_instances(
            InstanceIds=[
                instance_id
            ]
        )

        return response['Reservations'][0]['Instances'][0]['PublicIpAddress']

    @staticmethod
    def switch_elastic_ip_association(instance_id, allocation_id):
        ec2_client = boto3.client('ec2')

        ec2_client.associate_address(
            AllocationId=allocation_id,
            InstanceId=instance_id,
            AllowReassociation=True
        )

    @staticmethod
    def has_elastic_ip_association(instance_id):
        ec2_client = boto3.client('ec2')

        response = ec2_client.describe_instances(
            InstanceIds=[
                instance_id
            ]
        )

        ip_owner_id = response['Reservations'][0]['Instances'][0]['NetworkInterfaces'][0]['Association']['IpOwnerId']

        if ip_owner_id == 'amazon':
            return False

        return True

    @staticmethod
    def revoke_security_group_http_traffic(security_group_id):
        ec2_client = boto3.client('ec2')

        ec2_client.revoke_security_group_ingress(
            CidrIp='0.0.0.0/0',
            IpProtocol='tcp',
            FromPort=80,
            ToPort=80,
            GroupId=security_group_id
        )

    @staticmethod
    def authorize_security_group_http_traffic(security_group_id):
        ec2_client = boto3.client('ec2')

        ec2_client.authorize_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                {
                    'FromPort': 80,
                    'IpProtocol': 'tcp',
                    'IpRanges': [
                        {
                            'CidrIp': '0.0.0.0/0',
                            'Description': 'Allow HTTP Traffic'
                        },
                    ],
                    'ToPort': 80
                }
            ]
        )

    def determine_primary_server_health_status_and_switch(self):
        if self.primary_server_successful_health_check_count == self.healthy_threshold_count:
            self.primary_server_failed_health_check_count = 0
            self.primary_server_successful_health_check_count = 0
            self.primary_server_is_healthy = True

        if self.primary_server_failed_health_check_count == self.unhealthy_threshold_count:
            self.primary_server_failed_health_check_count = 0
            self.primary_server_successful_health_check_count = 0
            self.primary_server_is_healthy = False

        if self.primary_server_is_healthy and not self.has_elastic_ip_association(self.primary_server_instance_id):
            self.switch_elastic_ip_association(self.primary_server_instance_id, self.eip_allocation_id)
            self.revoke_security_group_http_traffic(self.failover_server_security_group_id)

        if not self.primary_server_is_healthy and not self.has_elastic_ip_association(self.failover_server_instance_id):
            self.switch_elastic_ip_association(self.failover_server_instance_id, self.eip_allocation_id)
            self.authorize_security_group_http_traffic(self.failover_server_security_group_id)

        self.health_check(self.get_ec2_ip_address(self.primary_server_instance_id))

    def run(self):
        schedule.every(self.health_check_interval_seconds).seconds.do(self.determine_primary_server_health_status_and_switch)

        while True:
            schedule.run_pending()
            time.sleep(1)


# tbc_health = TBCHttpHealthChecker(
#     3,
#     3,
#     10,
#     5,
#     'i-0c8a9aee4e4e34b2c',
#     'i-0d66e4bf25ff538ba',
#     'eipalloc-06dd48a65deb9cf59',
#     'sg-02c01b7a37ec2de99'
# )

# tbc_health.run()
