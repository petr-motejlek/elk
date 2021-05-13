# Overview

The solution consists of 2 parts:
- a "host" machine (under the `host/` directory)
  - responsible for creating a VM, installing all the necessary dependencies on it, and setting up to
    host the solution
  - "host" machine is the one that orchestrates the creation of the actual cluster
  - meant to make it easier to test this on solution on multiple different host operating
    systems, while still allowing me to control the environment
- the "cluster" directory
  - responsible for the actual cluster creation and setup; is meant to be run inside the "host VM"
  - for real production, this is the part of the solution that would likely be used on its own

# TLDR Usage

- Install Vagrant and either HyperV or VirtualBox and run the below commands in Powershell (Windows)
  or Bash (Mac/Linux/WSL).
  When using HyperV, `rsync` is also required in order for Vagrant to be able to forward the
  "cluster" directory into the "host" machine. Install it e.g. via `choco install rsync`.
  For WSL, the project needs to be cloned to `/mnt/c/...` and the `VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"`
  environment variable must be set. The support for WSL in Vagrant is still experimental though, and
  I do not recommend it just yet. (I have observed numerous random errors...)
- `cd host && vagrant up && vagrant ssh`
  - `cd cluster && terraform init && terraform apply -auto-approve -var dockerio_user=USER -var dockerio_token=TOKEN`
    The docker.io user and token are required as spinning up the cluster can be quite heavy on pulling images from
    Docker Hub (especially if you plan to repeat the process several times), and since they do have a limit on pulls
    (which I frequently run into :)), it's best to avoid it by registering a free account, generating a token for it,
    and providing it here. If you don't feel like providing the token on the command line, you can also use the
    `-input=true` flag, and Terraform will ask for them interactively. Alternatively, don't provide any arguments, and
    it will ask either way.
  - `curl http://kibana.elk.cls.local:5601`
  - `echo TEST | nc logstash.elk.cls.local 5042`
  - In case you want to be able to interact with the exposed services from outside the "host" machine,
    you can use `vagrant ssh -- -L 5601:kibana.elk.cls.local:5601 -L 5042:logstash.elk.cls.local:5042`
    in order to expose the services and their ports on your machine's localhost. NOTE: In Powershell, the command has to
    contain an additional `--%` sequence, e.g.
   `vagrant ssh --% -- -L 5601:kibana.elk.cls.local:5601 -L 5042:logstash.elk.cls.local:5042`.
    This is required in order for Powershell to stop parsing the rest of the command line, and then
    `--` tells Vagrant not to parse anything after it either. :)

# Background

I wanted to create a solution that is capable of spinning itself up in as few manual steps as possible.
Since many of the technologies do require some dependencies on the machine where the solution can be
created (and the orchestration itself requires several dependencies of its own), I chose to provide
a way for one to first spin up a VM (isolated from their system), install all the dependencies to it,
and then for the user of the solution to be able to simply log into the so-called "host" machine,
and only then trigger the actual cluster creation.

Reading through the requirements for the solution, I knew very early on I would be using Kubernetes.
Since my preferred way for spinning up a k8s cluster is to use Rancher's RKE, and that requires
a running Docker Engine on its nodes, and since the solution requirements were to write my own
Dockerfiles (and create the accompanying images) when using Docker, I also had to provide a way how
to build the images, push them into a registry that the k8s cluster can pull them from. So,
I ended up hosting an in-cluster private registry for this very purpose.

The in-cluster private registry is equipped with TLS certificates to authenticate itself to its clients.
Because of that, the "host" machine also has to know what the certificate authority (CA) that issued
those certificates is, hence one of the early steps in the cluster creation is to actually create a CA
and store itss certificate in the system store on the "host" machine. (This is one more reason why
I wanted to have this machine in the mix, because I really did not want to write into someone's system
store).

Furthermore, because I used loadbalancer for all the endpoints, it was also necessary, to be able to 
provide DNS resolution to the "host" machine.

All the custom Elastic Stack images are then built locally on the "host" machine, and eventually pushed into
the in-cluster registry, where k8s can then pull them from, as required. I wish I could have known of
an easy way to build the images inside the cluster (using Kaniko for instance), but that seemed too far
out the scope of this exercise :). I did not set up TLS for any of the ELK endpoints, as that was not
required, but I also think I've shown that I can do TLS with the registry, and spending time making TLS
work for these endpoints wouldn't be worth it. It would also make it harder to talk to those endpoints
on one's machine (outside the "host" machine). In production, we'd obviously do this, probably with
the help of cert-manager and/or Let's Encrypt or some other automated scheme for issuing certificates.

I did not wish to spend too much time on making everything production-grade (in fact I told myself
"I'll spend a week on this, no more, because I know I can make it superb, but nobody will
want to review that, if I spend too much time on it."), since production-grade and
"I have to make this runnable on somebody's laptop, and I can't have them install too many dependencies"
do not really go together well (for instance, this should ideally run on a 3+-node k8s cluster, but
even this 1-node setup has given me some trouble running on a laptop due to resource constraints, that
I opted to make it a 1-node, but allow the person using this to expand to more nodes if they wish).
Hence, some configuration is simply hardcoded into various places, even though it could be passed in as
variables (or similarly). However, I think I have displayed that I am able to do that, if necessary.
I also took very little care to squash the resulting Docker images by removing caches, and
intermediate layers. The official Dockerfile's even go as far as to compile their own `curl`, because
that leads to a smaller image :), but that felt too much out of the scope of this exercise.

Even though I used Helm for the dependencies, I specifically did not use it for the main ELK stack,
as it was not necessary to do that for this exercise. For production, I would do that. Similarly,
for production, I would go for a 3+-node k8s cluster. I would also keep the registry elsewhere. And
of course, the images for the ELK stack would be built elsewhere also.

For TLS, I would probably use an Ingress resource type in Kubernetes. I did not end up using it here,
as I had some trouble getting its service to receive a load-balanced IP address (I blamed RKE, but
it was much as likely my own mistake when setting it up). Did not wish to spend a lot of time debugging
that, so I ended up making the application (registry in this case) handle TLS directly.
Since it was requested for there to be a TCP port open for Logstash, TLS would have to be done slightly
differently for it, as officially TCP/UDP is not supported on Ingress resources. It could be done
on an application level (all the ELK components support that), but most of the ingress controllers
have their custom ways how to handle it, so it would definitely be possible to use an ingress controller
for TCP too.

# How does it work?

It all begins with the installation of the "host" machine. This requires Vagrant and either VirtualBox or
HyperV. The Vagrantfile instructs Vagrant to create a VM, install all the required dependencies onto it,
and copy the solution into it.

One then has to enter the "host" machine, and trigger the actual cluster creation. This uses Terraform
to orchestrate the entire process. Under the hood, Terraform uses 
- Vagrant to spin up the k8s node,
- RKE to install k8s cluster onto the node,
- Helm to install 
  - MetalLB (for load balancing the different services of the cluster),
  - k8s_gateway (for exposing the "cluster" DNS zone -- in order to resolve the load-balanced services),
  - Longhorn (for providing the cluster with persistent volumes).
- The in-cluster registry is then installed by deploying manifests into the cluster.
- The ELK stack's images are built.
- Then, finally, the ELK stack is deployed, using all of the above.

As requested, the Logstash instance is available outside the cluster at logstash.elk.cls.local:5042 (TCP), and
the Kibana instance is available at kibana.elk.cls.local:5601 (HTTP). When one wishes to talk to either of these,
the "host" machine can resolve these hostnames. It is also possible to talk to these endpoints from outside
the "host" machine, but one has to setup port forwarding using ssh (describe above in the TLDR part).

# Common pitfalls, some questions and some answers

## Why not an all-in-one solution?

Technically, the "host" Vagrantfile could also trigger terraform, during its provisioning, however,
there are too many moving pieces already, and some manual intervention might be required (such as
rerunning a failed command, etc), so I split it into two pieces.

## On HyperV, Vagrant times out before it begins provisioning the VM

I've seen it several times that the VM was up and running, but Vagrant just
cannot talk to it for some reason (this did happen on HyperV when it tried
to look up the host's IP in order to exchange some data over SMB/CIFS, and
it likely won't happen when using VirtualBox).
This happens at the very end of `vagrant up` when Vagrant is about to run
the provisioning step. In that case, simply run
`vagrant provision` or `vagrant up` manually, and then continue, please.
99 % of the time, it just continues properly.

## Why the downloaded charts?

Since Thursday evening, I am unable to fetch any Bitnami charts.
My requests end with HTTP/403. It seems to me like a bigger issue, as I tried
to perform the same request from another location (in case my IP/ISP was blocked)
and it failed the same way. Hence, I cloned the repositories with the charts
and included them in this one, to allow you to be able to use it.

## No Ansible/Chef/Puppet/...?

I thought that provisioning the created "host" and cluster machines through a shell script was
good enough for this exercise, but using Ansible for instance might have made it a bit
easier to read, as it uses a pretty YAML playbook to describe the end state, rather than a bunch
of random shell commands :). Ansible would be my choice because it does not really need any daemon
running anywhere to hold the state of the inventory.

## More k8s nodes

It is possible to edit the `cluster/Vagrantfile` and increase the number of nodes that the k8s cluster
will use. (In such case, I would also suggest increasing the number of replicas in `longhorn/main.tf` to 2 or 3).
In case one has a machine powerful enough to sustain them, feel free to use it. I had
a lot of trouble to get to these specific resource limitations in order to get one node running. 
Multiple nodes were not working properly due to CPU exhaustion on my laptop.

## Can it run without the "host" machine?

Yes, you can skip the hoist machine setup, in case your current machine already is running Ubuntu
and matches what `host/provision.sh` would do (you could even run that script as root). But 
the process does try to install the CA, it builds the docker images locally, etc. and you might
not want for that to remain on your machine.

## What's that special `archive` resource you're using with the Docker images?

The provider I used to build and push Docker images seems not to care about any
changes in the Docker build context directory. Hence, I had to come up with some
way for it to be able to realize that a change has happened. This seemed like
a good enough solution where I basically make terraform zip the Docker context,
compute a hash, and then use that hash as a parameter for the Docker build resource.

## Why `depends_on`?

Some components will create resources on the fly (Longhorn is a good example, where even
after the Helm process thinks everything has been deployed, it still takes it some time to begin
binding volumes). If I let Terraform scheudle the steps without intervention, it would try to spin
up the registry a lot sooner, and it would eventually time out. I know I could try to make the 
dependencies indirect by using some output of the previous steps/modules/resources, however,
using depends_on felt like a more straightforward way of making it explicit what needs to happen
when. I also only used it with `module`s (very high level).

# Can I interact with K8s?

Yes, you can. On the "host" machine, under `cluster`, there is `kubeconfig.yaml` created
when the cluster is up, and you can feed it into `kubectl` as `kubectl --kubeconfig kubeconfig.yaml`
and talk to the cluster.

# Further steps towards production-grade-ing this

# Monitoring

I did not include any explicit monitoring. There is a lot that can be collected. This system
has a lot of moving pieces. In the past I have used Nagios and Zabbix, so those might be the
first I would give a try, but I think I would leave the collection itself to Prometheus and
its agents, likely.

If I really wanted to do this as quickly as possible with what I know already, I'd likely
just create a DaemonSet to run zabbix agents (collecting the basic memory, CPU, etc utilization),
and have a deployment sitting there, being pushed the read values, sending out notifications,
and exposing its UI.

The ELK stack itself has integrated monitoring that could just be enabled and configured. Ideally, though,
I'd like to funnel everything into one system.

# Backing up

This is quite an extensive solution, and thus there's a plethora of different strategies we could take.

The easiest to implement would be to take snapshots of the entire "host" VM (since it contains everything), and back up
those snapshots. But the "host" VM is there only to make it easy to run this on somebody's laptop for review, let's ignore
such a simplistic case.

Since the ideal production scenario will use multiple nodes, a different technique would have to be used. Since the only state is
held by the persistent volumes, it should be enough to back those up. Longhorn supports snapshotting and snapshots can
be backed up elsewhere. To make disaster recovery quick, we could easily have machines ready to spin up a second cluster and
simply recreate the persistent volumes using the snapshots.

Alternatively, Longhorn also supports replicating the data to a backup location itself (on the fly). This could for instance
be configured to target an NFS share, S3, ...

Going up a layer, the ELK stack, specifically Elastic Search, does support snapshots also. One can create and attach
a physical volume to the pods, and let Elastic Search itself create a snapshot of its data. That snapshot can be periodically
replicated offsite, and used for disaster recovery.

We could also set up the backup scenario in a replicated fashion where logstash could have the pipeline configured to send data to two clusters.
In case one would ever go down, we would simply failover to the second one only. The second cluster would have to be running on a different
k8s cluster. This would be usable for disaster recovery, but since one of the clusters would be down, their data would be out of sync. Also, the
integrity of the data might be affected on a regular basis, as one cluster might receive an event from Logstash that the other did not (because of
some network issue for example). I would probably not recommend this.

Whatever we chose, we should implement a strategy where we regularly go through the exercise of taking down a k8s node for maintenance (upgrades, etc),
and making sure the strategy continues working. The worst case scenario would be if we implemented a strategy that we never really tried, and when
disaster occurs, we have no backup, because a cron job or something did not really run...
