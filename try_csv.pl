#! /usr/bin/perl -w

use strict;
use Text::CSV qw( csv) ;
use Data::Dumper;

my ($IP, $MAC, $MASK, $COMMENT, $GW);
my $scopes = CreateHash('ScopeId','scopes.csv');
#print Dumper $scopes;
my $reservations = CreateHash('IPAddress','reservations.csv');
#print Dumper $reservations;
#exit 1;
foreach $IP (keys %$reservations){
	my $template = createJSON($IP);
	print $template;
}

sub CreateHash{
	my $HashKey = shift;
	my $fn = shift;
	my %result;
	my $aoh = csv (
		in => "./$fn",
		headers => "auto"
	);
	
	foreach my $hash_ref (@{ $aoh }){
		my $Id = $$hash_ref{$HashKey};
		$result{$Id} = $hash_ref;
	}
	return \%result;
}


sub createJSON {
	my $IP = shift;
	#print Dumper $$reservations{$IP};
	# Remove dashes from MAC
	if ($$reservations{$IP}{'ClientId'} =~ /([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})/){
		$MAC ="$1$2$3$4$5$6"; 
	}else{
		$MAC = "undef";
	}
	$MASK = $$scopes{ $$reservations{$IP}{'ScopeId'} }{'SubnetMask'};
	# Description to comment
	$COMMENT = $$reservations{$IP}{'Description'};
	# Compose gateway from scope id
	if ($$reservations{$IP}{'ScopeId'} =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.\d{1,3}/){
		$GW = "$1.$2.$3.1";
	}else{
		$GW = "undef"
	}
	my $reg_template = << "END";
{
  "dhcp_server": {
    "ipv4": {
      "scope": {
        "static": [
          {
            "ip":"$IP",
            "mac":"$MAC",
            "enable":true,
            "name":"Test",
            "lease_time":1440,
            "default_gateway":"$GW",
            "netmask":"$MASK",
            "comment":"$COMMENT",
            "domain_name":"",
            "dns":{
                "server":{ 
                    "inherit":true
                    }
                },
            "wins":{
                "primary":"0.0.0.0",
                "secondary":"0.0.0.0"
                },
            "call_manager":{
                "primary":"",
                "secondary":"",
                "tertiary":""
                },
            "network_boot":{
                "next_server":"0.0.0.0",
                "boot_file":"",
                "server_name":""
                },
            "generic_option":{
                "group":"Default options"
                },
            "always_send_option":true

        }
        ]
      }
    }
  }
}
END
	return $reg_template;
}
