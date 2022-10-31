#! /usr/bin/perl -W

use strict;
use IO::Prompt;
use WWW::Curl::Easy;
use Data::Dumper;
use JSON;
use Text::CSV qw( csv );
use Net::Subnet qw( subnet_matcher );

my $server = prompt ("Enter firewall ip:", -d => "10.91.0.1");
my $user = prompt ("Username:", -d => "admin");
my $pass = prompt ("Password:", -e => "*");
my $reservations_file = prompt ("Reservation file:", -d => "reservations.csv");
my $scopes_file = prompt ("Scopes file:", -d => "scopes.csv");
my $c = WWW::Curl::Easy->new();


sub login { #	{{{1
	my $response;
	my $response_body;
	print "==LogIn==\n";
	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/auth");
	$c->setopt(CURLOPT_HEADER, "0");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_USERPWD, "$user:$pass");
	$c->setopt(CURLOPT_HTTPAUTH, CURLAUTH_ANY);
	#$c->setopt(CURLOPT_HTTPHEADER, "application/json");
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		print $response_body;
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			# Need to check config_mode in the reply
			my $response = decode_json($response_body);
			my %info = %{ ${ $$response{'status'}{'info'} }[0] };
			if ($info{'config_mode'} eq "No"){
				# Have to preempt
				if (preempt()){
					return 1;
				}else{
					# PreEmpt failed => bail out
					return 0;
				}
			}else{
				# No need to preempt
				return 1;
			}
		}else{
			# Login failed => bail out
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		return 0;
	}
}#	}}}
sub preempt {#	{{{1
	my $response;
	my $response_body;
	print "==PreEmpt==\n";
	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/config-mode");
	$c->setopt(CURLOPT_HEADER, "1");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_CUSTOMREQUEST, "POST");
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		#print "Transfer ok.\n";
		#my $response_code = $c->getinfo(CURLINFO_HTTP_CODE);
		#print "Response code: $response_code\n";
		print "PreEmpt response:\n $response_body";
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			return 1;
		}else{
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		return 0;
	}
}#	}}}
sub logout {#	{{{1
	my $response;
	my $response_body;
	print "==LogOut==\n";
	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/auth");
	$c->setopt(CURLOPT_HEADER, "1");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_CUSTOMREQUEST, "DELETE");
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			return 1;
		}else{
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		return 0;
	}
}#	}}}
sub  postJSON{#	{{{1
        my $EndPoint = shift;
	my $DataRef = shift;
	print "==PostJSON==\n";

	my $response;
	my $response_body;
	my @Headers = (
		"Content-Type: application/json",
		"Accept: application/json"
		);

	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/$EndPoint");
	$c->setopt(CURLOPT_HEADER, "0");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_CUSTOMREQUEST, "POST");
	$c->setopt(CURLOPT_POSTFIELDS, $DataRef);
	$c->setopt(CURLOPT_HTTPHEADER, \@Headers);
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			return 1;
		}else{
			print "Foutje 1\n";
			print Dumper $response_body;
			print $DataRef;
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		return 0;
	}
}#	}}}
sub commitChanges {#	{{{1
	my $response;
	my $response_body;
	print "==Commit==\n";
	my @Headers = (
		"Content-Type: application/json",
		"Accept: application/json"
		);

	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/config/pending");
	$c->setopt(CURLOPT_HEADER, "0");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_CUSTOMREQUEST, "POST");
	$c->setopt(CURLOPT_HTTPHEADER, \@Headers);
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			print Dumper $response_body;
			return 1;
		}else{
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		return 0;
	}
}#	}}}
sub getStaticScopes{#	{{{1
	my $response;
	my $response_body;
	print "==getStaticScopes==\n";
	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/dhcp-server/ipv4/scopes/static");
	$c->setopt(CURLOPT_HEADER, "0");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_CUSTOMREQUEST, "GET");
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			my %excisting_regs;
			# Lookis like the word true without quotes screws things up in decode_json
			$response_body =~ s/True/"True"/g;
			$response_body =~ s/true/"true"/g;
			my $response = decode_json($response_body);
			foreach my $hash_ref  (@{ $$response{"dhcp_server"}{"ipv4"}{"scope"}{"static"} }){
			  my $IP = $$hash_ref{"ip"};
			  $excisting_regs{$IP} = $hash_ref;
			}
			return \%excisting_regs;
		}else{
		        print("An error occured, HTTP code: " . $c->getinfo(CURLINFO_HTTP_CODE) ."\n");
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		return 0;
	}

}#	}}}
sub getInterfaces{#	{{{1
	my $response;
	my $response_body;
	print "==getInterfaces==\n";
	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/interfaces/ipv4");
	$c->setopt(CURLOPT_HEADER, "0");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_CUSTOMREQUEST, "GET");
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			my %interfaces;
			# Looks like the word true without quotes screws things up in decode_json
			$response_body =~ s/True/"True"/g;
			$response_body =~ s/true/"true"/g;
			my $response = decode_json($response_body);
			#print Dumper $response;
			foreach my $hash_ref  (@{ $$response{"interfaces"} }){
				my $IF;
				if ($$hash_ref{"ipv4"}{"vlan"}){
					$IF = $$hash_ref{"ipv4"}{"name"}."-".$$hash_ref{"ipv4"}{"vlan"};
				}else{
					$IF = $$hash_ref{"ipv4"}{"name"};
				}
				# Only interested in interfaces which have an IP assigned
				if ($$hash_ref{'ipv4'}{'ip_assignment'}{'mode'}{'static'}{'ip'}){
					$interfaces{$IF}= $$hash_ref{'ipv4'};
				}

			}
			return \%interfaces;
		}else{
		        print("An error occured, HTTP code: " . $c->getinfo(CURLINFO_HTTP_CODE) ."\n");
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		return 0;
	}

}#	}}}
sub createHash{ # {{{1
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
} # }}}
sub createJSON { # {{{1
	my $IP = shift;
	my $reservations = shift;
	my $scopes = shift;
	my $MAC;
	my $GW;
	#print Dumper $$reservations{$IP};
	# Remove dashes from MAC
	if ($$reservations{$IP}{'ClientId'} =~ /([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})/){
		$MAC ="$1$2$3$4$5$6"; 
	}else{
		$MAC = "undef";
	}
	my $MASK = $$scopes{ $$reservations{$IP}{'ScopeId'} }{'SubnetMask'};
	# Description to comment
	my $COMMENT = $$reservations{$IP}{'Description'};
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
            "enable":false,
            "name":"$COMMENT",
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
} # }}}

if ( login() ){
	print "Logged in\n";
	# Static scopes on a SonicWall are what others call reservation
	# Get te excisting ones to not do double work
	my $static_scopes = getStaticScopes();
	# Get the interfaces
	# See if the reservation is applicable for this firewall
	my $interfaces = getInterfaces();
	# Create a hash from the MS DHCP reservations export
	my $wantedReservations = createHash("IPAddress",$reservations_file);
	# Create a hash from the MS DHCP scopes export
	my $wantedScopes = createHash("ScopeId",$scopes_file);
	# Lets check to see which of those apply for the current firewall
	# Itterate the wanted reservation - indexed by IP
	foreach my $IP (keys %{ $wantedReservations }){
		# Check the interfaces to see if it belongs here
		foreach my $IF_Name (keys %{ $interfaces }){
			#print "$IP => $IF_Name => " .  $$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'ip'} .  " => " .  $$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'netmask'} .  "\n";
			my $is_subnet = subnet_matcher (
				$$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'ip'} .  "/" .  $$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'netmask'} 
			);
			if ($is_subnet->($IP)){
				#print "$IP zit in het subnet van $IF_Name\n";
				if (! $$static_scopes{$IP}){
					print "Reservering voor $IP bestaat nog niet.\n";
					my $reservation = createJSON($IP,$wantedReservations,$wantedScopes);
					postJSON("dhcp-server/ipv4/scopes/static",$reservation);
				}else{
					print "Reservering voor $IP bestaat al.\n";
				}
			}
		}
	}
	commitChanges();
	if( logout() ){
		print "Logged out again\n";
	}else{
		print "Logout failed\n";
	}
}else{
	print "Login failed\n";
} 

# vim: foldmethod=marker
