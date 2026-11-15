# Native CMake's bridge to Valve's actual shader generators. No makefiles.
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;

my ($mode, $source_dir, $project, $force_model) = @ARGV;
die "Usage: ShaderPrep.pl list|prepare SOURCE_DIR PROJECT 20b|30\n"
    unless defined($force_model) && $mode =~ /^(list|prepare)$/
        && $force_model =~ /^(20b|30)$/;

# Do not inherit the old batch build's inc-only mode or model override.
$ENV{dynamic_shaders} = 0;
$ENV{DIRECTX_FORCE_MODEL} = $force_model eq '30' ? '30' : '';
my $tools = File::Spec->catdir($source_dir, 'devtools', 'bin');
# The unmodified helper intentionally uses package globals (not strict).
require File::Spec->catfile($tools, 'valve_perl_helpers.pl');
my @expanded = LoadShaderListFile($project);
die "Shader list $project.txt is empty\n" unless @expanded;

# The 20b list contains ps2x aliases followed by dedicated ps20b sources for
# vertexlit_and_unlit_generic (both bump and non-bump). They share an output
# name, but have different combo declarations. Prefer the dedicated source;
# never send two #BEGIN blocks with the same name to shadercompile. For other
# aliases use the last list entry, consistently for headers and bytecode.
my (%selected, %dedicated, @order);
for my $shader (@expanded) {
    die "Unsupported non-FXC shader in $project: $shader\n"
        unless $shader =~ /^([^\r\n]+\.fxc)-----([\w]+)$/i;
    my ($source, $base) = ($1, $2);
    my $key = lc $base;
    my $exact = lc($source) eq lc("$base.fxc");
    push @order, $key unless exists $selected{$key};
    if (!exists($selected{$key}) || $exact || !$dedicated{$key}) {
        $selected{$key} = $shader;
        $dedicated{$key} = $exact;
    }
}
my @shaders = map { $selected{$_} } @order;

for my $shader (@shaders) {
    # These two collections contain FXC only. Do not silently send ASM shaders
    # through FXC: their old prep scripts require separate vsa/psa executables.
    die "Unsupported non-FXC shader in $project: $shader\n"
        unless $shader =~ /^([^\r\n]+\.fxc)-----([\w]+)$/i;
    my ($source, $base) = ($1, $2);
    die "Missing shader source: $source\n" unless -f $source;
    if ($mode eq 'list') {
        print "$shader\n";
        next;
    }
    my $prep = File::Spec->catfile($tools, 'fxc_prep.pl');
    print "Preparing $base\n";
    # List form bypasses shell command parsing, including paths with spaces.
    system { $^X } $^X, $prep, '-source', $source_dir, $shader;
    die "fxc_prep.pl failed for $shader (status $?)\n" if $? != 0;
    my $inc = File::Spec->catfile('fxctmp9_tmp', "$base.inc");
    die "fxc_prep.pl did not produce $inc\n" unless -s $inc;
}
