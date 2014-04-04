package VersionInfo;

##
# VersionInfo.pm
# Automatically updated by build script
##

use vars qw/$BRANCH $MAJOR $MINOR $BUILD_DATE $BUILD_ID/;
$BRANCH = "dev"; $MAJOR = "1.0.0"; $MINOR = "1"; $BUILD_DATE = "n/a"; $BUILD_ID = "n/a";

BEGIN
{
    use Exporter   ();
    use vars qw(@ISA @EXPORT @EXPORT_OK);

    @ISA		= qw(Exporter);
    @EXPORT		= qw(get_version);
	@EXPORT_OK	= qw();
}

sub get_version {
	return {
		Branch => $BRANCH,
		Major => $MAJOR,
		Minor => $MINOR,
		BuildDate => $BUILD_DATE,
		BuildID => $BUILD_ID
	};
}

1;
