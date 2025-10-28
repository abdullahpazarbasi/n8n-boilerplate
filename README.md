# n8n Boilerplate

Bu depo, n8n uygulamasını Kubernetes üzerinde çalıştırmak için gerekli kaynakları hazırlar.

## Kurulum

```sh
make setup
```

Komut, sisteminizde minikube mevcutsa küme kaynaklarını doğrudan uygular. Minikube
başlatılamazsa veya indirilemezse, `out/manifests` dizininde yeniden kullanılabilir
manifestler üretir. Küme, ingress denetleyicisi hazır hale gelmeden önce kaynak
uygulamasını engellerse, kurulum komutu ingress'i atlar ve yalnızca NodePort
üzerinden erişim sağlar.
