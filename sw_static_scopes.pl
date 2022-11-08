#! /usr/bin/perl -W

use strict;
use IO::Prompt;
use WWW::Curl::Easy;
use Data::Dumper;
use JSON;
use Text::CSV qw( csv );
use Net::Subnet qw( subnet_matcher );
use Template;

my $server = prompt ("Enter firewall ip:", -d => "10.91.0.1");
my $user = prompt ("Username:", -d => "admin");
my $pass = prompt ("Password:", -e => "*");
my $reservations_file = prompt ("Reservation file:", -d => "reservations.csv");
my $scopes_file = prompt ("Scopes file:", -d => "scopes.csv");
my $c = WWW::Curl::Easy->new();
my $tt = Template->new({
	INCLUDE_PATH => ".",
	INTERPOLATE => 1,
}) or die "$Template::ERROR\n";

my ($static_scopes, $dynamic_scopes, $interfaces, $wantedReservations, $wantedScopes);

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
	my $Method = shift;
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
	$c->setopt(CURLOPT_CUSTOMREQUEST, $Method);
	$c->setopt(CURLOPT_POSTFIELDS, $DataRef);
	$c->setopt(CURLOPT_HTTPHEADER, \@Headers);
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			print Dumper $response_body;
			return 1;
		}else{
			print "Foutje 1\n";
			print Dumper $response_body;
			print $DataRef;
			return 0;
		}

	}else{
		print("An error occured: $retcode\n".$c->strerror($retcode)." ".$c->errbuf."\n");
		print $DataRef;
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
			print Dumper $response_body;
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
sub getDynamicScopes{#	{{{1
	my $response;
	my $response_body;
	print "==getDynamicScopes==\n";
	$c->setopt(CURLOPT_URL, "https://$server/api/sonicos/dhcp-server/ipv4/scopes/dynamic");
	$c->setopt(CURLOPT_HEADER, "0");
	$c->setopt(CURLOPT_WRITEDATA, \$response_body);
	$c->setopt(CURLOPT_SSL_VERIFYHOST, "0");
	$c->setopt(CURLOPT_SSL_VERIFYPEER, "0");
	$c->setopt(CURLOPT_CUSTOMREQUEST, "GET");
	my $retcode = $c->perform();
	
	if ($retcode == 0){
		if ($c->getinfo(CURLINFO_HTTP_CODE) == 200){
			my %excisting_scopes;
			# Looks like the word true without quotes screws things up in decode_json
			$response_body =~ s/True/"True"/g;
			$response_body =~ s/true/"true"/g;
			my $response = decode_json($response_body);
			foreach my $hash_ref  (@{ $$response{"dhcp_server"}{"ipv4"}{"scope"}{"dynamic"} }){
				#print Dumper $hash_ref;
				my $IP = $$hash_ref{"from"};
				$excisting_scopes{$IP} = $hash_ref;
			}
			return \%excisting_scopes;
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
sub createDynamicScopes{ #{{{
	# Check to see which of those apply for the current firewall
	# Itterate the wanted scopes - indexed by ScopeID
	foreach my $start_ip (keys %{ $wantedScopes }){
		# Check the interfaces to see if it belongs here
		foreach my $IF_Name (keys %{ $interfaces }){
			# Setup a subnet matcher to check
			my $is_subnet = subnet_matcher (
				$$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'ip'} .  
				"/" .  
				$$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'netmask'} 
			);
			if ($is_subnet->($start_ip)){
				# $dynamic_scopes is indexed by start IP
				# Bestaat deze al dan niet maken
				my %data;
				$data{'START_RANGE'}   = $$wantedScopes{$start_ip}{'StartRange'}; 
				$data{'END_RANGE'}     = $$wantedScopes{$start_ip}{'EndRange'}; 
				$data{'GW'} = $$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'ip'};
				$data{'MASK'}    = $$wantedScopes{$start_ip}{'SubnetMask'}; 
				$data{'COMMENT'} = $$wantedScopes{$start_ip}{'Name'}; 
				my $scope;
				$tt->process('dynamic_scope.tt', \%data, \$scope) or die $tt->error(), "\n";
				#print $scope;
				if (! $$dynamic_scopes{$start_ip}){
					print "$start_ip bestaat nog niet interface $IF_Name, doing POST\n";
					if ( postJSON("dhcp-server/ipv4/scopes/dynamic",$scope,'POST') ){
						print  "Post ok\n";
					}else{
						print  "Post niet ok\n";
					}
				}else{
					print "$start_ip bestaat al\n";
					#if ( postJSON("dhcp-server/ipv4/scopes/dynamic",$scope,'PUT') ){
					#	print  "Put ok\n";
					#}else{
					#	print  "Put niet ok\n";
					#}
				}
			}
		}
	}
} # }}}
sub createStaticScopes{ #{{{1
	# Static scopes <=> Reservations
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
				my %data;
				$data{'IP'}   = $$wantedReservations{$IP}{'IPAddress'}; 
				# Remove dashes from MAC
				if ($$wantedReservations{$IP}{'ClientId'} =~ /([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})-([0-9a-fA-F]{2})/){
					$data{'MAC'} ="$1$2$3$4$5$6"; 
				}else{
					$data{'MAC'} = "undef";
				}
				$data{'NAME'}     = $$wantedReservations{$IP}{'Name'}; 
				$data{'COMMENT'}     = $$wantedReservations{$IP}{'Description'}; 
				$data{'GW'} = $$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'ip'};
				$data{'MASK'} = $$interfaces{$IF_Name}{'ip_assignment'}{'mode'}{'static'}{'netmask'};
				my $scope;
				$tt->process('static_scope.tt', \%data, \$scope) or die $tt->error(), "\n";
				if (! $$static_scopes{$IP}){
					print "Reservering voor $IP bestaat nog niet. Doing POST\n";
					postJSON("dhcp-server/ipv4/scopes/static",$scope, 'POST');
				}else{
					print "Reservering voor $IP bestaat al. Skipping\n";
					#postJSON("dhcp-server/ipv4/scopes/static",$scope, 'PUT');
				}
			}
		}
	}
} # }}}

if ( login() ){
	print "Logged in\n";
	# Get some information from the logged in firewall
	# Static scopes on a SonicWall are what others call reservation
	# Get te excisting ones to not do double work
	$static_scopes  = getStaticScopes();
	$dynamic_scopes = getDynamicScopes();
	$interfaces     = getInterfaces();

	# Create a hash from the MS DHCP exports
	$wantedReservations = createHash("IPAddress",$reservations_file);
	$wantedScopes       = createHash("StartRange",$scopes_file);

	# At this point we have all te information needed to create the dynamic and static scopes.
	#createDynamicScopes();
	createStaticScopes();

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
