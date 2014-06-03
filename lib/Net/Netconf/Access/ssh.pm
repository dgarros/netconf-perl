# child of Access

package Net::Netconf::Access::ssh;

use Expect;
use Net::Netconf::Trace;
use Net::Netconf::Access;
use Net::Netconf::Constants;
use Carp;
use File::Which;
our $VERSION ='0.01';

use vars qw(@ISA);
@ISA = qw(Net::Netconf::Access);

sub disconnect
{
    my ($self) = shift;
    $self->{'ssh_obj'}->soft_close();
}

sub start
{
    my($self) = @_;
    my $sshprog;

    # Get ssh port number if it exists
	$self->{'port'} 	= (getservbyname('ssh', 'tcp'))[2] unless defined $self->{'port'};
    $self->{'port'} 	= Net::Netconf::Constants::NC_DEFAULT_PORT unless ( defined $self->{'port'} or $self->{'server'} eq 'junoscript' );
    $self->{'server'} 	= 'netconf' unless $self->{'server'};

    my $openssh  = Net::OpenSSH->new(
						$self->{'hostname'},
						user      	=> $self->{'login'},
						password  	=> $self->{'password'},
						port 		=> $self->{'port'},
						master_opts => [-o => "ConnectTimeout=15", -o => "UserKnownHostsFile=/dev/null", -o => "StrictHostKeyChecking=no"],
						master_stderr_discard => 1,
					);
					
	$openssh->error and die "Unable to connect to remote host: " . $ssh->error;
	
	my ($pty, $pid) = $openssh->open2pty( { ssh_opts => '-s', }, $self->{'server'} );
	# tty => 0 
	my $ssh = Expect->init($pty);
	
    $ssh->log_stdout(0);
    $ssh->log_file($self->out);

	$self->{'openssh_obj'}	= $openssh;
    $self->{'ssh_obj'} 		= $ssh;
    $self;
}

sub send
{
    my ($self, $xml) = @_;
    my $ssh = $self->{'ssh_obj'};
    $xml .= ']]>]]>';
    print $ssh "$xml\r";
    1;
}

sub recv
{
    my $self = shift;
    my $xml;
    my $ssh = $self->{'ssh_obj'};
    if ($ssh->expect(600, ']]>]]>')) {
        $xml = $ssh->before() . $ssh->match();
    } else {
        print "Failed to login to $self->{'hostname'}\n";
        $self->{'seen_eof'} = 1;
    }
    $xml =~ s/]]>]]>//g;
    $xml;
}

sub out
{
    my $self = @_;
    foreach $line (@_) {
        if ($line =~ /Permission\ denied/) {
          print "Login failed: Permission Denied\n";
          $self->{'ssh_obj'}->hard_close();
          $self->{'seen_eof'} = 1;
        }
    }
}

1;

__END__

=head1 NAME

Net::Netconf::Access::ssh

=head1 SYNOPSIS

The Net::Netconf::Access::ssh module is used internally to provide ssh access to
a Net::Netconf::Access instance.

=head1 DESCRIPTION

This is a subclass of Net::Netconf::Access class that manages an ssh connection
with the destination host. The underlying mechanics for managing the ssh
connection is based on OpenSSH.

=head1 CONSTRUCTOR

new($ARGS)

Please refer to the constructor of Net::Netconf::Access class.

=head1 SEE ALSO

=over 4

=item *

Expect.pm

=item *

Net::Netconf::Access

=item *

Net::Netconf::Manager

=item *

Net::Netconf::Device

=back

=head1 AUTHOR

Juniper Networks Perl Team, send bug reports, hints, tips and suggestions to
netconf-support@juniper.net.

