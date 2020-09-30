# coordinate name change with aws_iam_policy_document.treeherder_rds in iam.tf
resource "aws_db_subnet_group" "treeherder-dbgrp" {
    name = "treeherder-dbgrp"
    description = "Treeherder DB subnet group"
    subnet_ids = ["${aws_subnet.treeherder-subnet-1a.id}",
                  "${aws_subnet.treeherder-subnet-1b.id}",
                  "${aws_subnet.treeherder-subnet-1d.id}",
                  "${aws_subnet.treeherder-subnet-1e.id}"]
    tags {
        Name = "treeherder-prod-dbgrp"
        App = "treeherder"
        Type = "dbgrp"
        Env = "prod"
        Owner = "relops"
        BugID = "1176486"
    }
}

# coordinate name change with aws_iam_policy_document.treeherder_rds in iam.tf
resource "aws_db_parameter_group" "treeherder-pg-mysql57" {
    name = "treeherder-mysql57"
    family = "mysql5.7"
    description = "Treeherder parameter group for MySQL 5.7"
    parameter {
        name = "character_set_server"
        value = "utf8"
    }
    parameter {
        name = "collation_server"
        value = "utf8_bin"
    }
    parameter {
        name = "log_bin_trust_function_creators"
        value = "1"
    }
    parameter {
        name = "log_output"
        value = "FILE"
    }
    parameter {
        name = "long_query_time"
        value = "2"
    }
    # Terminate SELECT queries that take longer than 180 seconds to complete.
    parameter {
        name = "max_execution_time"
        value = "180000"
    }
    parameter {
        name = "slow_query_log"
        value = "1"
    }
    parameter {
        name = "sql_mode"
        value = "NO_ENGINE_SUBSTITUTION,STRICT_ALL_TABLES"
    }
    parameter {
        name = "tx_isolation"
        value = "READ-COMMITTED"
    }
    parameter {
        name = "performance_schema"
        value = "1"
        apply_method = "pending-reboot"
    }
    # Original 200
    parameter {
        name = "innodb_io_capacity"
        value = "1000"
    }
    # Original 2000
    parameter {
        name = "innodb_io_capacity_max"
        value = "5000"
    }
    # Original 1024
    parameter {
        name = "innodb_lru_scan_depth"
        value = "256"
    }
    # Original 134217728
    parameter {
        name = "innodb_log_file_size"
        value = "17179869184"
        apply_method = "pending-reboot"
    }
    # Original 4
    parameter {
        name = "innodb_read_io_threads"
        value = "8"
        apply_method = "pending-reboot"
    }
    # Original 4
    parameter {
        name = "innodb_write_io_threads"
        value = "8"
        apply_method = "pending-reboot"
    }
    tags {
        Name = "treeherder-prod-pg-mysql57"
        App = "treeherder"
        Type = "pg"
        Env = "prod"
        Owner = "relops"
    }
}

resource "aws_db_parameter_group" "treeherder-dev-pg-mysql57" {
    name = "treeherder-dev-mysql57"
    family = "mysql5.7"
    description = "Treeherder dev parameter group for MySQL 5.7"
    parameter {
        name = "character_set_server"
        value = "utf8"
    }
    parameter {
        name = "collation_server"
        value = "utf8_bin"
    }
    parameter {
        name = "log_bin_trust_function_creators"
        value = "1"
    }
    parameter {
        name = "log_output"
        value = "FILE"
    }
    parameter {
        name = "long_query_time"
        value = "2"
    }
    # Terminate SELECT queries that take longer than 180 seconds to complete.
    parameter {
        name = "max_execution_time"
        value = "180000"
    }
    parameter {
        name = "slow_query_log"
        value = "1"
    }
    parameter {
        name = "sql_mode"
        value = "NO_ENGINE_SUBSTITUTION,STRICT_ALL_TABLES"
    }
    parameter {
        name = "tx_isolation"
        value = "READ-COMMITTED"
    }
    parameter {
        name = "performance_schema"
        value = "1"
        apply_method = "pending-reboot"
    }
    # Original 200
    parameter {
        name = "innodb_io_capacity"
        value = "1000"
    }
    # Original 2000
    parameter {
        name = "innodb_io_capacity_max"
        value = "2500"
    }
    # Original 1024
    parameter {
        name = "innodb_lru_scan_depth"
        value = "256"
    }
    # Original 11811160064
    parameter {
        name = "innodb_log_file_size"
        value = "8589934592"
        apply_method = "pending-reboot"
    }
    tags {
        Name = "treeherder-dev-prod-pg-mysql57"
        App = "treeherder"
        Type = "pg"
        Env = "dev"
        Owner = "relops"
    }
}

# Provides a way for dev/stage instances to reference the most recent prod RDS snapshot
# in `snapshot_identifier`, allowing them to be marked as tainted and automatically
# recreated with the latest prod dataset, using:
#    `terraform taint aws_db_instance.treeherder-{dev,stage}-rds`
data "aws_db_snapshot" "treeherder-prod-latest" {
    db_instance_identifier = "${aws_db_instance.treeherder-prod-rds.identifier}"
    most_recent = true
}

resource "aws_db_instance" "treeherder-dev-rds" {
    identifier = "treeherder-dev"
    snapshot_identifier = "${data.aws_db_snapshot.treeherder-prod-latest.id}"
    storage_type = "gp2"
    allocated_storage = 2000
    engine = "mysql"
    engine_version = "5.7.23"
    instance_class = "db.m5.xlarge"
    maintenance_window = "Sun:08:00-Sun:08:30"
    multi_az = false
    port = "3306"
    publicly_accessible = true
    parameter_group_name = "${aws_db_parameter_group.treeherder-dev-pg-mysql57.name}"
    auto_minor_version_upgrade = false
    skip_final_snapshot = true
    db_subnet_group_name = "${aws_db_subnet_group.treeherder-dbgrp.name}"
    vpc_security_group_ids = ["${aws_security_group.treeherder_heroku-sg.id}"]
    monitoring_role_arn = "arn:aws:iam::699292812394:role/rds-monitoring-role"
    monitoring_interval = 60
    performance_insights_enabled = true
    tags {
        Name = "treeherder-dev-rds"
        App = "treeherder"
        Type = "rds"
        Env = "dev"
        Owner = "relops"
        BugID = "1309395"
    }
    lifecycle {
        # Prevent the instance being recreated each time there is a new prod snapshot.
        ignore_changes = ["snapshot_identifier"]
    }
}

resource "aws_db_instance" "treeherder-stage-rds" {
    identifier = "treeherder-stage"
    snapshot_identifier = "${data.aws_db_snapshot.treeherder-prod-latest.id}"
    storage_type = "gp2"
    allocated_storage = 2000
    engine = "mysql"
    engine_version = "5.7.23"
    instance_class = "db.m5.xlarge"
    backup_retention_period = 1
    backup_window = "07:00-07:30"
    maintenance_window = "Sun:08:00-Sun:08:30"
    multi_az = false
    port = "3306"
    publicly_accessible = true
    parameter_group_name = "${aws_db_parameter_group.treeherder-pg-mysql57.name}"
    auto_minor_version_upgrade = false
    skip_final_snapshot = true
    db_subnet_group_name = "${aws_db_subnet_group.treeherder-dbgrp.name}"
    vpc_security_group_ids = ["${aws_security_group.treeherder_heroku-sg.id}"]
    monitoring_role_arn = "arn:aws:iam::699292812394:role/rds-monitoring-role"
    monitoring_interval = 60
    performance_insights_enabled = true
    tags {
        Name = "treeherder-stage-rds"
        App = "treeherder"
        Type = "rds"
        Env = "stage"
        Owner = "relops"
        BugID = "1176486"
    }
    lifecycle {
        # Prevent the instance being recreated each time there is a new prod snapshot.
        ignore_changes = ["snapshot_identifier"]
    }
}

resource "aws_db_instance" "treeherder-prod-rds" {
    identifier = "treeherder-prod"
    storage_type = "gp2"
    allocated_storage = 2000
    engine = "mysql"
    engine_version = "5.7.23"
    instance_class = "db.m5.2xlarge"
    username = "th_admin"
    password = "XXXXXXXXXXXXXXXX"
    backup_retention_period = 1
    backup_window = "07:00-07:30"
    maintenance_window = "Sun:08:00-Sun:08:30"
    multi_az = true
    port = "3306"
    publicly_accessible = true
    parameter_group_name = "${aws_db_parameter_group.treeherder-pg-mysql57.name}"
    auto_minor_version_upgrade = false
    db_subnet_group_name = "${aws_db_subnet_group.treeherder-dbgrp.name}"
    vpc_security_group_ids = ["${aws_security_group.treeherder_heroku-sg.id}"]
    monitoring_role_arn = "arn:aws:iam::699292812394:role/rds-monitoring-role"
    monitoring_interval = 60
    performance_insights_enabled = true
    tags {
        Name = "treeherder-prod-rds"
        App = "treeherder"
        Type = "rds"
        Env = "prod"
        Owner = "relops"
        BugID = "1276307"
    }
}

resource "aws_db_instance" "treeherder-prod-ro-rds" {
    identifier = "treeherder-prod-ro"
    replicate_source_db = "${aws_db_instance.treeherder-prod-rds.id}"
    storage_type = "gp2"
    allocated_storage = 2000
    engine = "mysql"
    engine_version = "5.7.23"
    instance_class = "db.m5.xlarge"
    maintenance_window = "Sun:08:00-Sun:08:30"
    multi_az = false
    port = "3306"
    publicly_accessible = true
    parameter_group_name = "${aws_db_parameter_group.treeherder-pg-mysql57.name}"
    auto_minor_version_upgrade = false
    vpc_security_group_ids = ["${aws_security_group.treeherder_heroku-sg.id}"]
    monitoring_role_arn = "arn:aws:iam::699292812394:role/rds-monitoring-role"
    monitoring_interval = 60
    performance_insights_enabled = false
    tags {
        Name = "treeherder-prod-ro-rds"
        App = "treeherder"
        Type = "rds"
        Env = "prod-ro"
        Owner = "relops"
        BugID = "1311468"
    }
}
