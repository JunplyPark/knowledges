#!/bin/sh
# Copyright 2015 The Rust Project Developers. See the COPYRIGHT
# file at the top-level directory of this distribution and at
# http://rust-lang.org/COPYRIGHT.
#
# Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
# http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
# <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
# option. This file may not be copied, modified, or distributed
# except according to those terms.

set -u

main() {
    set_globals "$@"
    handle_command_line_args "$@"
}

set_globals() {
    # Environment sanity checks
    assert_nz "$HOME" "\$HOME is undefined"
    assert_nz "$0" "\$0 is undefined"

    # Some constants
    version=0.0.1
    metadata_version=1

    # Find the location of the distribution server
    default_dist_server="https://static.rust-lang.org"
    insecure_dist_server="http://static-rust-lang-org.s3-website-us-west-1.amazonaws.com"
    dist_server="${RUSTUP_DIST_SERVER-$default_dist_server}"
    using_insecure_dist_server=false

    # Disable https if we can gpg because cloudfront often gets our files out of sync
    if [ "$dist_server" = "$default_dist_server" ]; then
	if command -v gpg > /dev/null 2>&1; then
	    dist_server="$insecure_dist_server"
	    using_insecure_dist_server=true
	fi
    fi

    # The directory on the server containing the dist artifacts
    rust_dist_dir=dist

    # Useful values pulled from the name of the invoked process
    rustup_cmd="$0"
    cmd_dirname="$(dirname "$0")"
    cmd_basename="$(basename "$0")"
    abs_cmd_basename="$(cd "$cmd_dirname" && pwd)"
    assert_nz "$cmd_dirname" "cmd_dirname"
    assert_nz "$cmd_basename" "cmd_basename"
    assert_nz "$abs_cmd_basename" "abs_cmd_basename"

    default_channel="nightly"

    # Set up the rustup data dir
    rustup_dir="${RUSTUP_HOME-$HOME/.rustup}"
    assert_nz "$rustup_dir" "rustup_dir"

    # We need to know whether the user has saved rustup data before, so that we
    # are sure not to overwrite it if they fail to pass --save.
    rustup_dir_already_exists=false
    if [ -e "$rustup_dir" ]; then
	rustup_dir_already_exists=true
    fi

    # Make sure our home dir is absolute. Once multirust is invoked, this
    # variables is carried through recursive toolchain invocations. If
    # some tool like Cargo changes directories, we want to be sure we can
    # find our home dir again.
    mkdir -p "$rustup_dir"
    need_ok "failed to create home directory"
    rustup_dir="$(cd "$rustup_dir" && pwd)"
    assert_nz "$rustup_dir" "rustup_dir"

    # Data locations
    version_file="$rustup_dir/version"
    manifests_dir="$rustup_dir/manifests"
    installer_dir="$rustup_dir/installers"
    channel_sums_dir="$rustup_dir/channel-sums"
    temp_dir="$rustup_dir/tmp"
    dl_dir="$rustup_dir/dl"

    # Set up the GPG key
    official_rust_gpg_key="
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

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
Mve696B5tlHyc1KxjHR6w9GRsh4=
=5FXw
-----END PGP PUBLIC KEY BLOCK-----
"

    if [ -n "${RUSTUP_GPG_KEY-}" ]; then
	gpg_key=`cat "$RUSTUP_GPG_KEY"`
    else
	gpg_key="$official_rust_gpg_key"
    fi

    # Check for some global command-line options
    flag_verbose=false
    flag_yes=false

    for opt in "$@"; do
	case "$opt" in
	    --verbose)
		flag_verbose=true
		;;

	    -y | --yes)
		flag_yes=true
		;;

	    --version)
		echo "rustup.sh $version"
		exit 0
		;;

	esac
    done

    if [ -n "${RUSTUP_VERBOSE-}" ]; then
	flag_verbose=true
    fi
}

# Verifies that ~/.rustup exists and uses the correct format
check_metadata_version() {
    verbose_say "checking metadata version"

    test -e "$rustup_dir"
    need_ok "rustup_dir must exist"

    if [ ! -e "$version_file" ]; then
	verbose_say "writing metadata version $metadata_version"
	echo "$metadata_version" > "$version_file"
    else
	local _current_version="$(cat "$version_file")"
	verbose_say "got metadata version $_current_version"
	if [ "$_current_version" != "$metadata_version" ]; then
	    # Wipe the out of date metadata
	    say "rustup metadata is out of date. deleting."
	    rm -Rf "$rustup_dir"
	    need_ok "failed to remove $rustup_dir"
	    mkdir -p "$rustup_dir"
	    need_ok "failed to create $rustup_dir"
	    echo "$metadata_version" > "$version_file"
	fi
    fi
}

handle_command_line_args() {
    local _save=false
    local _date=""
    local _prefix="/usr/local"
    local _uninstall=false
    local _channel="$default_channel"

    for arg in "$@"; do
	case "$arg" in
	    --save )
		_save=true
		;;
	    --uninstall )
		_uninstall=true
		;;
	esac

	if is_value_arg "$arg" "date"; then
	    _date="$(get_value_arg "$arg")"
	elif is_value_arg "$arg" "prefix"; then
	    _prefix="$(get_value_arg "arg")"
	fi
    done

    # All work is done in the ~/.rustup dir, which will be deleted
    # afterward if the user doesn't pass --save. *If* ~/.rustup
    # already exists and they *did not* pass --save, we'll pretend
    # they did anyway to avoid deleting their data.
    if [ "$_save" = false -a -e "$rustup_dir" ]; then
	_save=true
    fi

    # Make sure the metadata is compatible
    check_metadata_version

    local _toolchain="$_channel"
    if [ -n "$_date" ]; then
	_toolchain="$_toolchain-$_date"
    fi

    # OK, time to do the things
    if [ "$_uninstall" = false ]; then
	update_toolchain "$_toolchain" "$_prefix"
    else
	remove_toolchain "$_prefix"
    fi

    # Remove the temporary directory
    # FIXME: This will not be removed if an error occurred earlier
    if [ "$_save" = false ]; then
	rm -Rf "$rustup_dir"
	# Ignore errors
    fi
}

is_value_arg() {
    local _arg="$1"
    local _name="$2"

    echo "$arg" | grep -q -- "--$_name="
    return $?
}

get_value_arg() {
    local _arg="$1"

    echo "$arg" | cut -f2 -d=
}

# Updating toolchains

update_toolchain() {
    local _toolchain="$1"
    local _prefix="$2"

    is_toolchain_installed "$_prefix"
    local _is_installed="$RETVAL"

    if [ "$_is_installed" = true ]; then
	say "updating existing install for '$_toolchain'"
    else
	say "installing toolchain '$_toolchain'"
    fi

    install_toolchain_from_dist "$_toolchain" "$_prefix"
}

install_toolchain_if_not_installed() {
    local _toolchain="$1"

    is_toolchain_installed "$_toolchain"
    if [ "$RETVAL" = true ]; then
	say "using existing install for '$_toolchain'"
	return 0
    fi

    update_toolchain "$_toolchain"
}

install_toolchain_from_dist() {
    local _toolchain="$1"
    local _prefix="$2"

    if [ "$using_insecure_dist_server" = "true" ]; then
	say "gpg available. disabling https (avoids rust#21293)"
    fi

    determine_remote_rust_installer_location "$_toolchain"
    local _remote_rust_installer="$RETVAL"
    assert_nz "$_remote_rust_installer" "remote rust installer"
    verbose_say "remote rust installer location: $_remote_rust_installer"

    local _rust_installer_name="$(basename "$_remote_rust_installer")"
    assert_nz "$_rust_installer_name" "rust installer name"

    # Create a temp directory to put the downloaded toolchain
    make_temp_dir
    local _workdir="$RETVAL"
    assert_nz "$_workdir" "workdir"
    verbose_say "download work dir: $_workdir"

    # Download and install toolchain
    say "downloading checksums for rust installer from '$_remote_rust_installer'"
    download_checksum_for "$_remote_rust_installer" "$_workdir/$_rust_installer_name"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	exit 1
    fi

    say "downloading rust installer from '$_remote_rust_installer'"
    download_file_and_sig "$_remote_rust_installer" "$_workdir/$_rust_installer_name"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	exit 1
    fi
    check_file_and_sig "$_workdir/$_rust_installer_name"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	exit 1
    fi

    local _installer_file="$_workdir/$_rust_installer_name"
    install_toolchain "$_toolchain" "$_installer_file" "$_workdir" "$_prefix"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	err "failed to install toolchain"
    fi

    rm -R "$_workdir"
    need_ok "couldn't delete workdir"
}

install_toolchain() {
    local _toolchain="$1"
    local _installer="$2"
    local _workdir="$3"
    local _prefix="$4"

    local _installer_dir="$_workdir/$(basename "$_installer" | sed s/.tar.gz$//)"

    # Extract the toolchain
    tar xzf "$_installer" -C "$_workdir"
    if [ $? != 0 ]; then
	verbose_say "failed to extract installer"
	return 1
    fi

    # Install the toolchain
    local _toolchain_dir="$_prefix"
    verbose_say "installing toolchain to '$_toolchain_dir'"
    say "installing toolchain for '$_toolchain'"

    mkdir -p "$_toolchain_dir"
    if [ $? != 0 ]; then
	verbose_say "failed to create toolchain install dir"
	return 1
    fi

    sh "$_installer_dir/install.sh" --prefix="$_toolchain_dir" --disable-ldconfig
    if [ $? != 0 ]; then
	rm -R "$_toolchain_dir"
	verbose_say "failed to install toolchain"
	return 1
    fi

}

remove_toolchain() {
    local _prefix="$1"
    local _uninstall_script="$_prefix/lib/rustlib/uninstall.sh"

    if [ -e "$_uninstall_script" ]; then
	verbose_say "uninstalling from '$_uninstall_script'"
	sh "$_uninstall_script"
	need_ok "failed to remove toolchain"
	say "toolchain '$_toolchain' uninstalled"
    else
	say "no toolchain installed at '$_prefix'"
    fi
}

is_toolchain_installed() {
    local _prefix="$1"

    verbose_say "looking for installed toolchain '$_toolchain'"

    if [ -e "$_prefix/lib/rustlib" ]; then
	RETVAL=true
	return
    fi

    RETVAL=false
}

get_toolchain_dir() {
    local _toolchain="$1"

    if [ ! -e "$toolchains_dir" ]; then
	verbose_say "creating toolchains dir '$toolchains_dir'"
	mkdir -p "$toolchains_dir"
	need_ok "failed to make toolchain dir"
    fi

    RETVAL="$toolchains_dir/$_toolchain"
}


# Custom toolchain installation

update_custom_toolchain_from_dir() {
    local _toolchain="$1"
    local _custom_toolchain="$2"
    update_custom_toolchain_from_dir_common "$_toolchain" "$_custom_toolchain" false
}

update_custom_toolchain_from_link() {
    local _toolchain="$1"
    local _custom_toolchain="$2"
    update_custom_toolchain_from_dir_common "$_toolchain" "$_custom_toolchain" true
}

update_custom_toolchain_from_dir_common() {
    local _toolchain="$1"
    local _custom_toolchain="$2"
    local _create_link="$3"

    check_custom_toolchain_name "$_toolchain"

    if [ ! -e "$_custom_toolchain" ]; then
	err "specified path does not exist $_custom_toolchain"
    fi

    local _expected_rustc="$_custom_toolchain/bin/rustc"
    if [ ! -e "$_expected_rustc" ]; then
	err "no rustc in custom toolchain at '$_expected_rustc'"
    fi

    maybe_remove_existing_custom_toolchain "$_toolchain"

    get_toolchain_dir "$_toolchain"
    local _toolchain_dir="$RETVAL"
    local _custom_toolchain_dir="$(cd $_custom_toolchain && pwd)"

    if [ "$_create_link" = true ]; then
	say "creating link from $_custom_toolchain_dir"
	ln -s "$_custom_toolchain_dir" "$_toolchain_dir"
	need_ok "failed to create link to toolchain"
    else
	say "copying from $_custom_toolchain_dir"
	cp -R "$_custom_toolchain_dir" "$_toolchain_dir"
	need_ok "failed to copy toolchain direcotry"
    fi
}

update_custom_toolchain_from_installers() {
    local _toolchain="$1"
    local _installers="$2"

    check_custom_toolchain_name "$_toolchain"

    maybe_remove_existing_custom_toolchain "$_toolchain"

    make_temp_dir
    local _workdir="$RETVAL"
    assert_nz "$_workdir" "workdir"
    verbose_say "download work dir: $_workdir"

    # Used for cleanup
    get_toolchain_dir "$_toolchain"
    local _toolchain_dir="$RETVAL"
    assert_nz "$_toolchain_dir" "toolchain dir"

    # Iterate through list of installers installing each
    while [ -n "$_installers" ]; do

	# Pull out the first installer
	local _installer="$(echo "$_installers" | cut -f1 -d,)"
	need_ok "failed to parse installer"
	assert_nz "$_installer" "installer"

	# Remove that installer from the list
	local _next_installers="$(echo "$_installers" | sed s/[^,]*,//)"
	need_ok "failed to shift installer list"

	# If that was the last installer...
	if [ "$_next_installers" = "$_installers" ]; then
	    _next_installers=""
	fi

	_installers="$_next_installers"

	case "$_installer" in
	    *://* )
		(cd "$_workdir" && curl -f -O "$_installer")
		if [ $? != 0 ]; then
		    rm -R "$_workdir"
		    rm -Rf "$_toolchain_dir"
		    err "failed to download toolchain"
		fi
		local _local_installer="$_workdir/$(basename "$_installer")"
		;;

	    * )
		local _local_installer="$_installer"
		;;
	esac

	install_toolchain "$_toolchain" "$_local_installer" "$_workdir"
	if [ $? != 0 ]; then
	    rm -R "$_workdir"
	    rm -Rf "$_toolchain_dir"
	    err "failed to install toolchain"
	fi
    done

    rm -R "$_workdir"
    need_ok "failed to remomve work dir"
}

# When updating custom toolchains always blow away whatever already
# exists. If we don't do this then raw 'directory' toolchains that
# don't use the installer could end up breaking things.
maybe_remove_existing_custom_toolchain() {
    local _toolchain="$1"

    is_toolchain_installed "$_toolchain"
    local _is_installed="$RETVAL"

    if [ "$_is_installed" = true ]; then
	say "removing existing toolchain before the update"
	remove_toolchain "$_toolchain"
    fi
}

check_custom_toolchain_name() {
    local _toolchain="$1"

    case "$_toolchain" in
	nightly | beta | stable | \
	nightly-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | \
	beta-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | \
	stable-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] )
	    err "invalid custom toolchain name: '$_toolchain'"
	    ;;
    esac
}


# Default and override

find_override_toolchain_or_default() {
    if find_override; then
	RETVAL="$RETVAL_TOOLCHAIN"
	return
    fi

    find_default
    RETVAL="$RETVAL_TOOLCHAIN"
}

find_default() {
    if [ ! -e "$default_file" ]; then
	err 'no default toolchain configured. run `multirust help default`'
    fi

    local _default="$(cat "$default_file")"
    assert_nz "$_default" "default file is empty"

    get_toolchain_dir "$_default"
    local _sysroot="$RETVAL"
    assert_nz "$_sysroot" "sysroot"

    if [ ! -e "$_sysroot" ]; then
	err "toolchain '$_default' not installed. run \`multirust update $_default\` to install"
    fi

    RETVAL_TOOLCHAIN="$_default"
    RETVAL_SYSROOT="$_sysroot"
}

find_override() {
    if [ ! -e "$override_db" ]; then
	return 1
    fi

    local _dir="$(pwd)"
    assert_nz "$_dir" "empty starting dir"

    # Go up the directory hierarchy looking for overrides
    while [ "$_dir" != "/" -a "$_dir" != "." ]; do
	while read _line; do
	    local _ovrdir="$(echo "$_line" | cut -d $delim -f1)"
	    need_ok "extracting record from db failed"
	    assert_nz "$_ovrdir" "empty dir in override db"
	    local _toolchain="$(echo "$_line" | cut -d $delim -f2)"
	    need_ok "extracting record from db failed"
	    assert_nz "$_toolchain" "empty toolchain in override db"

	    if [ "$_dir" = "$_ovrdir" ]; then
		RETVAL_OVRDIR="$_ovrdir"
		RETVAL_TOOLCHAIN="$_toolchain"
		get_toolchain_dir "$_toolchain"
		RETVAL_SYSROOT="$RETVAL"
		if [ ! -e "$RETVAL_SYSROOT" ]; then
		    err "toolchain '$_toolchain' not installed. run \`multirust update $_toolchain\` to install"
		fi
		return
	    fi
	done < "$override_db"

	local _dir="$(dirname $_dir)"
    done

    return 1
}

set_default() {
    local _toolchain="$1"

    make_temp
    local _workfile="$RETVAL"
    assert_nz "$_workfile" "workfile"

    echo "$_toolchain" > "$_workfile"
    if [ $? != 0 ]; then
	rm -R "$_workfile"
	err "couldn't write default toolchain to tempfile"
    fi

    mv -f "$_workfile" "$default_file"
    if [ $? != 0 ]; then
	rm -R "$_workfile"
	err "couldn't set default toolchain"
    fi

    say "default toolchain set to '$_toolchain'"
}

set_override() {
    local _toolchain="$1"

    local _override_dir="$(pwd)"
    assert_nz "$_override_dir" "empty pwd?"

    # Escape forward-slashes
    local _escaped_override_dir=`echo "$_override_dir" | sed s/\\\//\\\\\\\\\\\//g`

    make_temp
    local _workfile="$RETVAL"
    assert_nz "$_workfile" "workfile"

    # Copy the current db to a new file, removing any existing override
    if [ -e "$override_db" ]; then
	# Escape the tab because OS X sed won't
	sed "/^$_escaped_override_dir$delim/d" "$override_db" > "$_workfile"
	if [ $? != 0 ]; then
	    rm -R "$_workfile"
	    err "unable to edit override db"
	fi
    fi

    # Append the new override
    echo "$_override_dir$delim$_toolchain" >> "$_workfile"
    if [ $? != 0 ]; then
	rm -R "$_workfile"
	err "unable to edit override db"
    fi

    # Move it back to the database
    mv -f "$_workfile" "$override_db"
    need_ok "unable to edit override db"

    say "override toolchain for '$_override_dir' set to '$_toolchain'"
}

remove_override() {
    local _override_dir="$(pwd)"
    assert_nz "$_override_dir" "empty pwd?"

    # Escape forward-slashes
    local _escaped_override_dir=`echo "$_override_dir" | sed s/\\\//\\\\\\\\\\\//g`

    make_temp
    local _workfile="$RETVAL"
    assert_nz "$_workfile" "workfile"

    # Check if the override exists
    local _have_override=false
    if [ -e "$override_db" ]; then
	# Get an actual tab character because grep doesn't interpret \t
	egrep "^$_escaped_override_dir$delim" "$override_db" > /dev/null
	if [ $? = 0 ]; then
	    local _have_override=true
	fi
    fi
    if [ $_have_override = false ]; then
	say "no override for current directory '$_override_dir'"
	return
    fi

    # Copy the current db to a new file, removing any existing override
    if [ -e "$override_db" ]; then
	sed "/^$_escaped_override_dir$delim/d" "$override_db" > "$_workfile"
	if [ $? != 0 ]; then
	    rm -R "$_workfile"
	    err "unable to edit override db"
	fi
    fi

    # Move it back to the database
    mv -f "$_workfile" "$override_db"
    need_ok "unable to edit override db"

    say "override toolchain for '$_override_dir' removed"
}


# Manifest interface

determine_remote_rust_installer_location() {
    local _toolchain="$1"

    verbose_say "determining remote rust installer for '$_toolchain'"

    case "$_toolchain" in
	nightly | beta | stable | nightly-* | beta-* | stable-* )
	    download_rust_manifest "$_toolchain"
	    get_local_rust_manifest_name "$_toolchain"
	    local _manifest_file="$RETVAL"
	    assert_nz "$_manifest_file" "manifest file"
	    get_remote_installer_location_from_manifest "$_toolchain" "$_manifest_file" rust "$rust_dist_dir"
	    return
	    ;;

	* )
	    say "interpreting toolchain spec as explicit version"
	    get_architecture
	    local _arch="$RETVAL"
	    assert_nz "$_arch" "arch"

	    local _file_name="rust-$_toolchain-$_arch.tar.gz"
	    RETVAL="$dist_server/$rust_dist_dir/$_file_name"
	    return
	    ;;
    esac
}

download_rust_manifest() {
    local _toolchain="$1"

    case "$_toolchain" in
	nightly | beta | stable )
	    local _remote_rust_manifest="$dist_server/$rust_dist_dir/channel-rust-$_toolchain"
	    ;;

	nightly-* | beta-* | stable-* )
	    extract_channel_and_date_from_toolchain "$_toolchain"
	    local _channel="$RETVAL_CHANNEL"
	    local _date="$RETVAL_DATE"
	    assert_nz "$_channel" "channel"
	    assert_nz "$_date" "date"
	    local _remote_rust_manifest="$dist_server/$rust_dist_dir/$_date/channel-rust-$_channel"
	    ;;

	*)
	    err "unrecognized toolchain spec: $_toolchain"
	    ;;

    esac

    get_local_rust_manifest_name "$_toolchain"
    local _local_rust_manifest="$RETVAL"
    assert_nz "$_local_rust_manifest" "local rust manifest"

    download_manifest "$_toolchain" "rust" "$_remote_rust_manifest" "$_local_rust_manifest"
}

download_manifest()  {
    local _toolchain="$1"
    local _name="$2"
    local _remote_manifest="$3"
    local _local_manifest="$4"

    verbose_say "remote $_name manifest: $_remote_manifest"
    verbose_say "local $_name manifest: $_local_manifest"

    verbose_say "creating manifests dir '$manifests_dir'"
    mkdir -p "$manifests_dir"
    need_ok "couldn't create manifests dir"

    say "downloading $_name manifest for '$_toolchain'"
    download_and_check "$_remote_manifest" "$_local_manifest"
}

get_remote_installer_location_from_manifest() {
    local _toolchain="$1"
    local _manifest_file="$2"
    local _package_name="$3"
    local _dist_dir="$4"

    if [ ! -e "$_manifest_file" ]; then
	err "manifest file '$_manifest_file' does not exist"
    fi

    get_architecture
    local _arch="$RETVAL"
    assert_nz "$_arch" "arch"

    while read _line; do
	# This regex checks for the version in addition to the package name because there
	# are package names that are substrings of other packages, 'rust-docs' vs. 'rust'.
	echo "$_line" | egrep "^$_package_name-(nightly|beta|alpha|[0-9]).*$_arch\.tar\.gz" > /dev/null
	if [ $? = 0 ]; then
	    case "$_toolchain" in
		nightly | beta | stable )
		    RETVAL="$dist_server/$_dist_dir/$_line"
		    ;;

		nightly-* | beta-* | stable-* )
		    extract_channel_and_date_from_toolchain "$_toolchain"
		    local _channel="$RETVAL_CHANNEL"
		    local _date="$RETVAL_DATE"
		    assert_nz "$_channel" "channel"
		    assert_nz "$_date" "date"
		    RETVAL="$dist_server/$_dist_dir/$_date/$_line"
		    ;;

		*)
		    err "unrecognized toolchain spec: $_toolchain"
		    ;;
	    esac
	    return
	fi
    done < "$_manifest_file"

    err "couldn't find remote installer for '$_arch' in manifest"
}

extract_channel_and_date_from_toolchain() {
    local _toolchain="$1"

    case "$_toolchain" in
	nightly-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | \
	beta-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | \
	stable-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] )
	    local _channel="$(echo "$_toolchain" | cut -d- -f1)"
	    local _date="$(echo "$_toolchain" | cut -d- -f2,3,4)"
	    RETVAL_CHANNEL="$_channel"
	    RETVAL_DATE="$_date"
	    ;;

	*)
	    err "unrecognized toolchain spec: $_toolchain"
	    ;;

    esac
}

get_local_rust_manifest_name() {
    local _toolchain="$1"

    RETVAL="$manifests_dir/channel-rust-$_toolchain"
}


# Reporting

show_default() {
    if find_default; then
	local _toolchain="$RETVAL_TOOLCHAIN"
	local _sysroot="$RETVAL_SYSROOT"

	say "default toolchain: $_toolchain"
	say "default location: $_sysroot"

	push_toolchain_ldpath "$_toolchain"

	echo

	"$_sysroot/bin/rustc" --version
	"$_sysroot/bin/cargo" --version

	pop_toolchain_ldpath
    else
	say "no default"
    fi
}

show_override() {
    if find_override; then
	local _ovrdir="$RETVAL_OVRDIR"
	local _toolchain="$RETVAL_TOOLCHAIN"
	local _sysroot="$RETVAL_SYSROOT"

	say "override directory: $_ovrdir"
	say "override toolchain: $_toolchain"
	say "override location: $_sysroot"

	push_toolchain_ldpath "$_toolchain"

	echo

	"$_sysroot/bin/rustc" --version
	"$_sysroot/bin/cargo" --version

	pop_toolchain_ldpath
    else
	say "no override"
    fi
}

list_overrides() {
    if [ -e "$override_db" ]; then
	local _overrides="$(cat "$override_db" | sort)"
	if [ -n "$_overrides" ]; then
	    echo "$_overrides"
	else
	    say "no overrides"
	fi
    else
	say "no overrides"
    fi
}

list_toolchains() {
    if [ -e "$toolchains_dir" ]; then
	local _toolchains="$(cd "$toolchains_dir" && ls | sort)"
	if [ -n "$_toolchains" ]; then
	    echo "$_toolchains"
	else
	    say "no installed toolchains"
	fi
    else
	say "no installed toolchains"
    fi
}


# Management of data in the MULTIRUST_HOME directory

delete_data() {
    if [ ! "$flag_yes" = true ]; then
	read -p "This will delete all toolchains, overrides, aliases, and other multirust data associated with this user. Continue? (y/n) " yn

	case "$yn" in
	    [Nn] )
		exit 0
		;;
	esac
    fi

    # Need -f for Cargo's write-protected git directories
    rm -Rf "$rustup_dir"
    need_ok "failed to delete '$rustup_dir'"
}


# The multirustproxy control interface

ctl_print_override_toolchain_or_default() {
    find_override_toolchain_or_default
    echo "$RETVAL"
}

ctl_print_toolchain_sysroot() {
    local _toolchain="$1"

    get_toolchain_dir "$_toolchain"
    echo "$RETVAL"
}

ctl_maybe_print_update_notice_for_toolchain() {
    local _toolchain="$1"

    if [ -e "$update_list_file" ]; then
	if grep -q "$_toolchain" "$update_list_file" ; then
	    say "a new version of '$_toolchain' is available. run \`multirust update $_toolchain\` to install it"
	fi
    fi
}

ctl_maybe_check_for_updates_async() {
    local _now="$(date +%F)"
    local _need_update=true
    if [ -e "$update_stamp_file" ]; then
	local _update_time="$(cat "$update_stamp_file")"
	if [ "$_now" = "$_update_time" ]; then
	    local _need_update=false
	fi
    fi

    # This is so the test runner can disable this non-deterministic
    # behavior and avoid tripping over other processes writing to .multirust
    if [ -n "${MULTIRUST_DISABLE_UPDATE_CHECKS-}" ]; then
	verbose_say "update checks disabled"
	return
    fi

    if [ "$_need_update" = true ]; then
	verbose_say "update timestamp out of date. checking for updates"
	echo "$_now" > "$update_stamp_file"
	# Call multirust recursively in background to look for updates
	call_multirust ctl check-updates-sync > /dev/null 2>&1 &
    else
	verbose_say "update timestamp up to date. not checking for updates"
    fi
}

# Checks whether the checksums of the available nightly/beta/stable installers differ
# from the installed toolchains, and if so adds the channel to the update list so
# later invocations of multirust can notify the user.
ctl_check_for_updates_sync() {
    for _channel in nightly beta stable; do
	if [ -e "$update_list_file" ]; then
	    if grep -q "$_channel" "$update_list_file"; then
		verbose_say "channel '$_channel' already needs update. skipping"
		continue
	    fi
	fi

	determine_remote_rust_installer_location "$_channel"
	local _remote_rust_installer="$RETVAL"
	assert_nz "$_remote_rust_installer" "remote rust installer"

	local _local_sumfile="$channel_sums_dir/$_channel.sha256"
	local _remote_sumfile="$_remote_rust_installer.sha256"
	verbose_say "local sumfile: $_local_sumfile"
	verbose_say "remote sumfile: $_remote_sumfile"
	if [ -e "$_local_sumfile" ]; then
	    verbose_say "checking for updates on $_channel"
	    make_temp_dir
	    local _workdir="$RETVAL"
	    assert_nz "$_workdir" "workdir"
	    verbose_say "update work dir: $_workdir"

	    (cd "$_workdir" && curl -f -O "$_remote_sumfile" > /dev/null 2>&1)
	    if [ $? != 0 ]; then
		verbose_say "couldn't download checksums for $_channel"
	    else
		local _local_sum="$(cat "$_local_sumfile")"
		local _new_sum="$(cat "$_workdir/$(basename "$_remote_sumfile")")"

		if [ "$_local_sum" != "$_new_sum" ]; then
		    if [ -e "$update_list_file" ]; then
			local _newlist="$_workdir/newlist"
			cp "$update_list_file" "$_newlist"
			if [ $? != 0 ]; then
			    rm -R "$_workdir"
			    err "couldn't delete copy update list"
			fi

			if ! grep -q "$_channel" "$_newlist"; then
			    verbose_say "adding $_channel to existing update list"
			    echo "$_channel" >> "$_newlist"
			    if [ $? != 0 ]; then
				rm -R "$_workdir"
				err "couldn't append update list"
			    fi
			    mv -f "$_newlist" "$update_list_file"
			    if [ $? != 0 ]; then
				rm -R "$_workdir"
				err "couldn't replace update list"
			    fi
			else
			    # This should be rare since we've already avoided doing the download
			    # if the channel was in the list. But could be possible with races
			    # in multiple invocations.
			    verbose_say "channel $_channel already in update list"
			fi
		    else # Update list does not exist
			verbose_say "adding $_channel to new update list"
			local _newlist="$_workdir/newlist"
			echo "$_channel" > "$_newlist"
			if [ $? != 0 ]; then
			    rm -R "$_workdir"
			    err "couldn't append update list"
			fi
			mv -f "$_newlist" "$update_list_file"
			if [ $? != 0 ]; then
			    rm -R "$_workdir"
			    err "couldn't replace update list"
			fi
		    fi
		fi

		rm -R "$_workdir"
		need_ok "couldn't delete workdir"
	    fi
	else # Channel not installed
	    verbose_say "channel '$_channel' not installed. not checking for updates"
	fi
    done
}


# Tools

call_multirust() {
    "$multirust_cmd" "$@"
}

# FIXME: Temp names based on pid need to worry about pid recycling
make_temp_name() {
    local _pid="$$"
    assert_nz "$_pid" "pid"

    local _tmp_number="${NEXT_TMP_NUMBER-0}"
    local _tmp_name="tmp-$_pid-$_tmp_number"
    NEXT_TMP_NUMBER="$(expr "$_tmp_number" + 1)"
    assert_nz "$NEXT_TMP_NUMBER" "NEXT_TMP_NUMBER"
    RETVAL="$_tmp_name"
}

make_temp() {
    mkdir -p "$temp_dir"
    need_ok "failed to make temp dir '$temp_dir'"

    make_temp_name
    local _tmp_name="$temp_dir/$RETVAL"
    touch "$_tmp_name"
    need_ok "couldn't make temp file '$_tmp_name'"
    RETVAL="$_tmp_name"
}

make_temp_dir() {
    mkdir -p "$temp_dir"
    need_ok "failed to make temp dir '$temp_dir'"

    make_temp_name
    local _tmp_name="$temp_dir/$RETVAL"
    mkdir -p "$_tmp_name"
    need_ok "couldn't make temp dir '$_tmp_name'"
    RETVAL="$_tmp_name"
}

# Returns 0 on success, like sha256sum
check_sums() {
    local _sumfile="$1"

    # Hackily edit the sha256 file to workaround a bug in the bots' generation of sums
    make_temp_dir
    local _workdir="$RETVAL"
    assert_nz "$_workdir" "workdir"

    sed s/tmp\\/dist\\/.*\\/final\\/// "$_sumfile" > "$_workdir/tmpsums"
    need_ok "failed to generate temporary checksums"

    local _sumfile_dirname="$(dirname "$_sumfile")"
    assert_nz "$_sumfile_dirname" "sumfile_dirname"
    (cd "$_sumfile_dirname" && shasum -c -a 256 "$_workdir/tmpsums" > /dev/null)
    local _sum_retval=$?

    rm -R "$_workdir"
    need_ok "couldn't delete workdir '$_workdir'"

    return $_sum_retval
}

get_architecture() {

    verbose_say "detecting architecture"

    local _ostype="$(uname -s)"
    local _cputype="$(uname -m)"

    verbose_say "uname -s reports: $_ostype"
    verbose_say "uname -m reports: $_cputype"

    if [ "$_ostype" = Darwin -a "$_cputype" = i386 ]; then
	# Darwin `uname -s` lies
	if sysctl hw.optional.x86_64 | grep -q ': 1'; then
	    local _cputype=x86_64
	fi
    fi

    case "$_ostype" in

	Linux)
	    local _ostype=unknown-linux-gnu
	    ;;

	FreeBSD)
	    local _ostype=unknown-freebsd
	    ;;

	DragonFly)
	    local _ostype=unknown-dragonfly
	    ;;

	Darwin)
	    local _ostype=apple-darwin
	    ;;

	MINGW* | MSYS*)
	    err "unimplemented windows arch detection"
	    ;;

	*)
	    err "unrecognized OS type: $_ostype"
	    ;;

    esac

    case "$_cputype" in

	i386 | i486 | i686 | i786 | x86)
            local _cputype=i686
            ;;

	xscale | arm)
	    local _cputype=arm
            ;;

	armv7l)
            local _cputype=arm
            local _ostype="${_ostype}eabihf"
            ;;

	x86_64 | x86-64 | x64 | amd64)
            local _cputype=x86_64
            ;;

	*)
            err "unknown CPU type: $CFG_CPUTYPE"

    esac

    # Detect 64-bit linux with 32-bit userland
    if [ $_ostype = unknown-linux-gnu -a $_cputype = x86_64 ]; then
	file -L "$SHELL" | grep -q "x86[_-]64"
	if [ $? != 0 ]; then
	    local _cputype=i686
	fi
    fi

    local _arch="$_cputype-$_ostype" 
    verbose_say "architecture is $_arch"

    RETVAL="$_arch"
}

check_sig() {
    local _sig_file="$1"

    if ! command -v gpg > /dev/null 2>&1; then
	say "gpg not found. not verifying signatures"
	return
    fi

    make_temp_dir
    local _workdir="$RETVAL"
    assert_nz "$_workdir" "workdir"
    verbose_say "sig work dir: $_workdir"

    echo "$gpg_key" > "$_workdir/key.asc"
    need_ok "failed to serialize gpg key"

    # Convert the armored key to .gpg format so it works with --keyring
    verbose_say "converting armored key to gpg"
    gpg --dearmor "$_workdir/key.asc"
    if [ $? != 0 ]; then
	exit 1
	rm -R "$_workdir"
	return 1
    fi

    say "verifying signature '$_sig_file'"
    gpg --keyring "$_workdir/key.asc.gpg" --verify "$_sig_file"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	return 1
    fi

    rm -R "$_workdir"
    need_ok "failed to delete workdir"
    return 0
}

# Downloads a remote file, its checksum, and signature and verifies them
download_and_check() {
    local _remote_name="$1"
    local _local_name="$2"

    local _remote_sums="$_remote_name.sha256"
    local _local_sums="$_local_name.sha256"

    local _remote_basename="$(basename "$_remote_name")"

    make_temp_dir
    local _workdir="$RETVAL"
    assert_nz "$_workdir" "workdir"
    verbose_say "download work dir: $_workdir"

    download_checksum_for "$_remote_name" "$_workdir/$_remote_basename"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	exit 1
    fi
    download_file_and_sig "$_remote_name" "$_workdir/$_remote_basename"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	exit 1
    fi
    check_file_and_sig "$_workdir/$_remote_basename"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	exit 1
    fi

    mv -f "$_workdir/$_remote_basename" "$_local_name"
    need_ok "failed to mv $_local_name"
    mv -f "$_workdir/$_remote_basename.sha256" "$_local_name.sha256"
    need_ok "failed to mv $_local_name.sha256"
    mv -f "$_workdir/$_remote_basename.asc" "$_local_name.asc"
    need_ok "failed to mv $_local_name.asc"

    rm -R "$_workdir"
    need_ok "couldn't delete workdir '$_workdir'"
}

download_checksum_for() {
    local _remote_name="$1"
    local _local_name="$2"

    local _remote_sums="$_remote_name.sha256"
    local _local_sums="$_local_name.sha256"

    local _remote_basename="$(basename "$_remote_name")"
    local _remote_sums_basename="$_remote_basename.sha256"
    assert_nz "$_remote_basename" "remote basename"

    make_temp_dir
    local _workdir="$RETVAL"
    assert_nz "$_workdir" "workdir"
    verbose_say "download work dir: $_workdir"

    say "downloading '$_remote_sums' to '$_workdir'"
    (cd "$_workdir" && curl -f -O "$_remote_sums")
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	say_err "couldn't download checksum file '$_remote_sums'"
	return 1
    fi

    verbose_say "moving '$_workdir/$_remote_sums_basename' to '$_local_sums'"
    mv -f "$_workdir/$_remote_sums_basename" "$_local_sums"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	err "couldn't move '$_workdir/$_remote_sums_basename' to '$_local_sums'"
    fi

    rm -R "$_workdir"
    need_ok "couldn't delete workdir '$_workdir'"
}

download_file_and_sig() {
    local _remote_name="$1"
    local _local_name="$2"

    local _remote_sums="$_remote_name.sha256"
    local _local_sums="$_local_name.sha256"

    local _remote_sig="$_remote_name.asc"
    local _local_sig="$_local_name.asc"

    local _remote_basename="$(basename "$_remote_name")"
    local _remote_sums_basename="$_remote_basename.sha256"
    local _remote_sig_basename="$_remote_basename.asc"
    assert_nz "$_remote_basename" "remote basename"

    local _local_basename="$(basename "$_local_name")"
    assert_nz "$_local_basename" "local basename"

    make_temp_dir
    local _workdir="$RETVAL"
    assert_nz "$_workdir" "workdir"
    verbose_say "download work dir: $_workdir"

    say "downloading '$_remote_sig' to '$_workdir'"
    (cd "$_workdir" && curl -f -O "$_remote_sig")
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	say_err "couldn't download signature file '$_remote_sig'"
	return 1
    fi

    # Create the dl directory for this artifact based
    # on the checksum so we can find it to resume later.
    verbose_say "local checksums: $_local_name.sha256"
    if [ ! -e "$_local_name.sha256" ]; then
	err "local checksum for remote file not in expected location"
    fi
    local _dl_dir="$(cat "$_local_name.sha256" | shasum -a 256 | head -c 10)"
    need_ok "failed to calculate temporary download file name"
    verbose_say "dl dir: $dl_dir/$_dl_dir"
    mkdir -p "$dl_dir/$_dl_dir"
    need_ok "failed to create temporary download dir"

    say "downloading '$_remote_name' to '$dl_dir/$_dl_dir'"
    # Invoke curl in a way that will resume if necessary
    (cd "$dl_dir/$_dl_dir" && curl -C - -f -O "$_remote_name")
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	rm -R "$dl_dir/$_dl_dir"
	say_err "couldn't download '$_remote_name'"
	return 1
    fi

    mv "$dl_dir/$_dl_dir/$_remote_basename" "$_workdir/$_remote_basename"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	rm -R "$dl_dir/$_dl_dir"
	err "couldn't move file from dl dir to work dir"
    fi

    rm -R "$dl_dir/$_dl_dir"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	err "failed to remove dl dir"
    fi

    verbose_say "moving '$_workdir/$_remote_basename' to '$_local_name'"
    mv -f "$_workdir/$_remote_basename" "$_local_name"
    if [ $? != 0 ]; then
	rm -R "$_workdir"
	err "couldn't move '$_workdir/$_remote_basename' to '$_local_name'"
    fi

    verbose_say "moving '$_workdir/$_remote_sig_basename' to '$_local_sig'"
    mv -f "$_workdir/$_remote_sig_basename" "$_local_sig"
    if [ $? != 0 ]; then
	rm "$_local_name"
	rm -R "$_workdir"
	err "couldn't move '$_workdir/$_remote_sig_basename' to '$_local_sig'"
    fi

    rm -R "$_workdir"
    need_ok "couldn't delete workdir '$_workdir'"
}

check_file_and_sig() {
    local _local_name="$1"

    local _local_sums="$_local_name.sha256"
    local _local_sig="$_local_name.asc"

    say "verifying checksums for '$_local_name'"
    check_sums "$_local_sums"
    if [ $? != 0 ]; then
	say_err "checksum failed for '$_local_name'"
	return 1
    fi

    check_sig "$_local_sig"
    if [ $? != 0 ]; then
	say_err "signature failed for '$_local_name'"
	return 1
    fi
}

push_toolchain_ldpath() {
    local _toolchain="$1"

    get_toolchain_dir "$_toolchain"
    local _toolchain_dir="$RETVAL"
    local _new_path="$_toolchain_dir/lib"

    OLD_LD_LIBRARY_PATH="${LD_LIBRARY_PATH-}"
    LD_LIBRARY_PATH="$_new_path:${LD_LIBRARY_PATH-}"
    export LD_LIBRARY_PATH

    OLD_DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH-}"
    DYLD_LIBRARY_PATH="$_new_path:${DYLD_LIBRARY_PATH-}"
    export DYLD_LIBRARY_PATH
}

pop_toolchain_ldpath() {
    LD_LIBRARY_PATH="$OLD_LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH
    DYLD_LIBRARY_PATH="$OLD_DYLD_LIBRARY_PATH"
    export DYLD_LIBRARY_PATH
}


# The help system

display_topic() {
    local _topic="$1"

    local _multirust_src="$cmd_dirname/multirust"

    extract_topic_from_source "$_multirust_src" "$_topic"

    if [ $? != 0 ]; then
	err "unrecognized topic '$_topic'"
    fi
}

extract_topic_from_source() {
    local _source="$1"
    local _topic="$2"

    local _tagged_docs="$(awk "/<$_topic>/,/<\/$_topic>/" "$_source")"
    local _docs="$(echo "$_tagged_docs" | sed '1d' | sed '1d' | sed '$d' | sed 's/^\# \?//')"

    echo "$_docs"

    if [ $? != 0 ]; then
	return $?
    fi

    if [ -z "$_docs" ]; then
	return 1
    fi

    return 0
}


# Standard utilities

say() {
    echo "rustup: $1"
}

say_err() {
    say "$1" >&2
}

verbose_say() {
    if [ "$flag_verbose" = true ]; then
	say "$1"
    fi
}

err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! command -v $1 > /dev/null 2>&1
    then err "need $1"
    fi
}

need_ok() {
    if [ $? != 0 ]; then err "$1"; fi
}

assert_nz() {
    if [ -z "$1" ]; then err "assert_nz $2"; fi
}

# Ensure various commands exist
need_cmd dirname
need_cmd basename
need_cmd mkdir
need_cmd cat
need_cmd curl
need_cmd mktemp
need_cmd rm
need_cmd egrep
need_cmd grep
need_cmd file
need_cmd uname
need_cmd tar
need_cmd sed
need_cmd sh
need_cmd mv
need_cmd awk
need_cmd cut
need_cmd sort
need_cmd shasum
need_cmd date
need_cmd head

main "$@"
