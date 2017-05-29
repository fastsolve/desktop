#!/usr/bin/env python

"""
Launch Jupyter Notebook within a Docker notebook image and
automatically open up the URL in the default web browser.
"""

# Author: Xiangmin Jiao <xmjiao@gmail.com>

from __future__ import print_function  # Only Python 2.x

import sys
import subprocess
import time


def parse_args(description):
    "Parse command-line arguments"

    import argparse

    # Process command-line arguments
    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument('-u', "--user",
                        help='username used by the image. ' +
                        ' The default is to retrieve from image.',
                        default="")

    parser.add_argument('-i', '--image',
                        help='The Docker image to use. ' +
                        'The default is fastsolve/desktop.',
                        default="fastsolve/desktop")
    parser.add_argument('-t', '--tag',
                        help='Tag of the image. The default is latest. ' +
                        'If the image already has a tag, its tag prevails.',
                        default="latest")

    parser.add_argument('-p', '--pull',
                        help='Pull the latest Docker image. ' +
                        ' The default is not to pull.',
                        dest='pull', action='store_true')

    parser.set_defaults(pull=False)

    parser.add_argument('notebook', nargs='?',
                        help='The notebook to open.', default="")

    args = parser.parse_args()
    image = args.image

    # Append tag to image if the image has no tag
    if image.find(':') < 0:
        image += ':' + args.tag

    return image, args.user, args.pull, args.notebook


def random_ports(port, n):
    """Generate a list of n random ports near the given port.

    The first 5 ports will be sequential, and the remaining n-5 will be
    randomly selected in the range [port-2*n, port+2*n].
    """
    import random

    for i in range(min(5, n)):
        yield port + i
    for i in range(n - 5):
        yield max(1, port + random.randint(-2 * n, 2 * n))


def id_generator(size=6):
    """Generate a container ID"""
    import random
    import string

    chars = string.ascii_uppercase + string.digits
    return "desktop_" + (''.join(random.choice(chars) for _ in range(size)))


def find_free_port(port, retries):
    "Find a free port"
    import socket

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    for prt in random_ports(port, retries + 1):
        try:
            sock.bind(("127.0.0.1", prt))
            sock.close()
            return prt
        except socket.error:
            continue

    print("Error: Could not find a free port.")
    sys.exit(-1)


def handle_interrupt():
    """Handle keyboard interrupt"""
    try:
        print("Press Ctrl-C again to stop the server: ")
        time.sleep(5)
        print('Invalid response. Resuming...')
    except KeyboardInterrupt:
        print('*** Stopping the server.')
        subprocess.Popen(["docker", "exec", container,
                          "killall", "startvnc.sh"],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        sys.exit(0)


if __name__ == "__main__":
    import os
    import webbrowser
    import platform

    image, user, pull, notebook = parse_args(description=__doc__)

    pwd = os.getcwd()
    homedir = os.path.expanduser('~')
    if platform.system() == "Linux":
        uid = str(os.getuid())
    else:
        uid = ""

    img = subprocess.check_output(['docker', 'images', '-q', image])
    if pull or not img:
        try:
            err = subprocess.call(["docker", "pull", image])
        except BaseException:
            err = -1

        if err:
            sys.exit(err)

        # Delete dangling image
        if img and subprocess.check_output(['docker', 'images', '-f',
                                            'dangling=true',
                                            '-q']).find(img) >= 0:
            subprocess.Popen(["docker", "rmi", "-f", img.decode('utf-8')[:-1]])

    # Generate a container ID and find an unused port
    container = id_generator()
    port_http = str(find_free_port(8888, 50))

    # Create directory .ssh if not exist
    if not os.path.exists(homedir + "/.ssh"):
        os.mkdir(homedir + "/.ssh")

    if user:
        docker_home = "/home/" + user
    else:
        docker_home = subprocess.check_output(["docker", "run", "--rm", image,
                                               "echo $DOCKER_HOME"]). \
            decode('utf-8')[:-1]

    volumes = ["-v", pwd + ":" + docker_home + "/shared"]

    print("Starting up docker image...")

    # Start the docker image in the background and pipe the stderr
    subprocess.call(["docker", "run", "-d", "--rm", "--name", container,
                     "-p", "127.0.0.1:" + port_http + ":" + port_http,
                     "--env", "HOST_UID=" + uid] +
                    volumes +
                    ["-w", docker_home + "/shared",
                     image,
                     "jupyter-notebook --no-browser --ip=0.0.0.0 --port " +
                     port_http +
                     " >> " + docker_home + "/.log/jupyter.log 2>&1"])

    wait_for_url = True
    # Wait for user to press Ctrl-C
    while True:
        try:
            if wait_for_url:
                # Wait until the file is not empty
                while not subprocess.check_output(["docker", "exec", container,
                                                   "cat", docker_home +
                                                   "/.log/jupyter.log"]):
                    time.sleep(1)

                p = subprocess.Popen(["docker", "exec", container,
                                      "tail", "-F",
                                      docker_home + "/.log/jupyter.log"],
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE,
                                     universal_newlines=True)

                # Monitor the stdout to extract the URL
                for stdout_line in iter(p.stdout.readline, ""):
                    ind = stdout_line.find("http://0.0.0.0:")

                    if ind >= 0:
                        # Open browser if found URL
                        if not notebook:
                            url = "http://localhost:" + stdout_line[ind+15:-1]
                        else:
                            url = "http://localhost:" + port_http + \
                                "/notebooks/" + notebook + \
                                stdout_line[stdout_line.find("?token="):-1]

                        print("Copy/paste this URL into your browser " +
                              "when you connect for the first time:")
                        print("    ", url)
                        webbrowser.open(url)
                        p.stdout.close()
                        p.terminate()
                        wait_for_url = False
                        break

            print("Press Ctrl-C to stop the server.")

            # Wait till the container exits or Ctlr-C is pressed
            subprocess.check_output(["docker", "exec", container,
                                     "tail", "-f", "/dev/null"])
        except subprocess.CalledProcessError:
            try:
                # If Docker process no long exists, exit
                if not subprocess.check_output(['docker', 'ps',
                                                '-q', '-f',
                                                'name=' + container]):
                    print('Docker container is no longer running')
                    sys.exit(-1)
                time.sleep(1)
            except KeyboardInterrupt:
                handle_interrupt()

            continue
        except KeyboardInterrupt:
            handle_interrupt()
        except OSError:
            sys.exit(-1)
