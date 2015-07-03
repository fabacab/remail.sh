# `remail.sh` - README

`remail.sh` is a simple [Cypherpunk anonymous remailer](https://en.wikipedia.org/wiki/Cypherpunk_anonymous_remailer) message preprocessor that makes it easy to chain multiple [anonymous remailers](https://en.wikipedia.org/wiki/Anonymous_remailer) together. You give it a message to prepare and an arbitrary-length remailer chain, and it outputs the prepared message that you should send to a remailer. For example, the following command will prepare the message contained in `message.txt` for delivery to `recipient@example.com` through the 2-hop remailer chain `mixmaster@remailer1.com` -> `mixmaster@remailer2.com`:

    ./remail.sh message.txt recipient@example.com \
        mixmaster@remailer1.com \
        mixmaster@remailer2.com

You can chain an arbitrary number of remailers one after the other like this; you're not limited to just two. `remail.sh`'s output is the prepared message. Just pipe its output to your MTA for use in automated scripts:

    ./remail.sh message.txt recipient@example.com \ 
        mixmaster@remailer1.com \
        mixmaster@remailer2.com \
            | sendmail mixmaster@remailer1.com

Some good documentation about this process is provided by [remailer.paranoici.org](http://remailer.paranoici.org/howto.php), so read that first if you're new to remailers. The gist, however, is that encryption proceeds in the reverse order of the delivery chain; first, your message is encrypted for delivery to the last remailer used (the "exit node"), then the next-to-last, and so on. This way, your identity is protected from most adversaries unless every node in your multi-hop remailer chain is conspiring against you.

If you have the ultimate recipient's PGP public key (the key for `recipient@example.com`, in the above example), you can also optionally encrypt the message contents itself by adding the `--encrypt-message` flag:

    ./remail.sh --encrypt-message message.txt recipient@example.com \
        mixmaster@remailer1.com \
        mixmaster@remailer2.com

This way, both your identity and your message are protected from discovery against an evil exit node.

For more options, invoke `remail.sh` with the `--help` flag.

## Security considerations

These should probably go without saying, but I'll say it anyway:

* Do _not_ sign email intended to be anonymous. Signing a message identifies you as its author, effectively de-anonymizing you. If you want to send something anonymously, then don't sign it. (Duh?)
* Use at least 2 (or even 3) remailers in your chain. A single remailer is probably enough for casual use, but if you really intend to make tracing your identity difficult, you should use a longer chain. If you only use one remailer, you're putting all your faith in that one server. This is probably unwise for any serious use case.
* Consider using a Type II ("Mixmaster") or Type III ("Mixminion") remailer instead; the Type I ("Cypherpunk") remailers supported by this tool are old and probably not secure against government or large corporate adversaries such as the NSA. While this technique will probably suffice for most weaker targets, you really shouldn't use this tool for doing anything that would piss off your government (not that there's anything wrong with pissing off your government, but still...).

Finally: **truly anonymous email is very hard to pull off safely. Use this software at your own risk. I take no responsibility for and make no guarantees about the security or integrity of this software.**

## Known issues

* `remail.sh` assumes you already have the PGP public keys for all of the remailers in your chain. If you don't, it'll break.
* `remail.sh` also assumes every remailer in your chain _requires_ the use of PGP encryption. This isn't technically correct, but it probably should be. :P Alternatively, you can use the `--no-encrypt` flag, in which case `remail.sh` assumes _none_ of the remailers in your chain require encryption, which can be useful for debugging but is probably not what you want to do (and see the `--debug` flag, too).

Patches are welcome. ;)

## Alternatives

Why `remail.sh` instead of, say, [`premail`](http://manpages.ubuntu.com/manpages/natty/man1/premail.1.html)?

* Simplicity: `remail.sh` does one thing and one thing only. That's the point. If you want to make chummus, use a food processor. If you want to eat a chickpea, a food processor gets in your way.
* Education: Dovetailing from the previous point, something simpler is easier to learn, both in terms of how to use it and what it's actually doing for you. Privacy is as much about knowing _why_ to do something as it is about knowing _how_ to do something.
* Portability: `remail.sh` is a simple BASH shell script. No need to install a package. Just download and run it in any BASH shell.

Also, bluntly, because I wanted an excuse to do more shell scripting. I'm masochistic like that. :P
