# tmc-kgetconf
get kubeconfig from tmc using fuzzy find and tmux menus for ease of use


--debug      Show debug values\
--realname   Use real supervisor cluster names instead of common name label\
--viewconf   View current ~/.kube/config configured clusters\
--getconf    Fetch kubeconfig from TMC\
--walk       Browse through Supervisor->Cluster->Namespace\
--help       Hopefully this is


requires fzf\
requires fzf-tmux\
requires tmux\
requires csvtools
