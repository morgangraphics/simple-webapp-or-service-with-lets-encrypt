# Deploying a secure web application in production with


```terminal

  ██╗     ███████╗████████╗███████╗    ███████╗███╗   ██╗ ██████╗██████╗ ██╗   ██╗██████╗ ████████╗
  ██║     ██╔════╝╚══██╔══╝██╔════╝    ██╔════╝████╗  ██║██╔════╝██╔══██╗╚██╗ ██╔╝██╔══██╗╚══██╔══╝
  ██║     █████╗     ██║   ███████╗    █████╗  ██╔██╗ ██║██║     ██████╔╝ ╚████╔╝ ██████╔╝   ██║   
  ██║     ██╔══╝     ██║   ╚════██║    ██╔══╝  ██║╚██╗██║██║     ██╔══██╗  ╚██╔╝  ██╔═══╝    ██║   
  ███████╗███████╗   ██║   ███████║    ███████╗██║ ╚████║╚██████╗██║  ██║   ██║   ██║        ██║   
  ╚══════╝╚══════╝   ╚═╝   ╚══════╝    ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝        ╚═╝   

                                               ██╗                                                           
                                               ██║                                                           
                                            ████████╗                                                        
                                            ██╔═██╔═╝                                                        
                                            ██████║                                                          
                                            ╚═════╝                                                          

                       ██████╗███████╗██████╗ ████████╗██████╗  ██████╗ ████████╗                              
                      ██╔════╝██╔════╝██╔══██╗╚══██╔══╝██╔══██╗██╔═══██╗╚══██╔══╝                              
                      ██║     █████╗  ██████╔╝   ██║   ██████╔╝██║   ██║   ██║                                 
                      ██║     ██╔══╝  ██╔══██╗   ██║   ██╔══██╗██║   ██║   ██║                                 
                      ╚██████╗███████╗██║  ██║   ██║   ██████╔╝╚██████╔╝   ██║                                 
                       ╚═════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═════╝  ╚═════╝    ╚═╝
```

## Making iptables rules permanent

[Deploying a secure web application in production with Let's Encrypt and Certbot](Readme.md) details a way to deploy an app or service securely. In doing so, it takes advantage of [iptables](https://en.wikipedia.org/wiki/Iptables) rules to intercept traffic on port 80 or 443 and reroute that traffic to the port your app or service is runming on.

## Debian/Ubuntu Based Instructions

1.  Install the `iptables-persistent` package

    Newer \*Nix Distros

    ```bash
    sudo apt install iptables-persistent
    ```

    Older \*Nix Distros

    ```bash
    sudo apt-get install iptables-persistent
    ```

1.  Save your newly updated iptables rules to a file

    ```bash
    sudo iptables-save > /etc/iptables/rules.v4
    ```

## RedHat/CentOS Based Instructions

1.  Save your newly updated iptables rules to a file

    ```bash
    sudo service iptables save
    ```

1.  Restart the service

    ```bash
    sudo service iptables restart
    ```

1.  Make them permanent

    ```bash
    sudo chkconfig iptables on
    ```
