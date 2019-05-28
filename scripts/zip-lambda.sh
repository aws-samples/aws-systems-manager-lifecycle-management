# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

cd workflow
zip lifecycle_fn.zip index.py
zip workflow_fn.zip index-workflow.py
zip check_node_status_fn.zip check_node_status_fn.py
zip check_rs_status_fn.zip check_rs_status_fn.py
zip init_rs_fn.zip init_rs_fn.py
zip add_node_rs_fn.zip add_node_rs_fn.py
cd ..
