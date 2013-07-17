package PLite;
use PhiloPurple::Lite;

enable_session;

__PACKAGE__->setting(
    handle_static => 1,
);

any '/' => sub {
    my $c = shift;

    my $count = $c->session->get('counter');
    $c->session->set(counter => ++$count);

    $c->render('index.tx', {
        counter => $count,
    });
};

1;

__DATA__
@@ index.tx
<h1>It Works!</h1>
<p>あなたは<: $counter :>回目の訪問ですね</p>

@@ /index.txt
あいうえお
