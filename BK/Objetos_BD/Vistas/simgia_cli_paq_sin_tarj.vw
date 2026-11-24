create or replace force view it.simgia_cli_paq_sin_tarj as
select fue_obt_nro_doc_persona(gcli.cod_persona) nro_documento,
       fue_obt_nom_persona(gcli.cod_persona) nombre_persona,
       gpcli.fec_inicio fec_inicio,
       (select a.nro_cuenta from ge_paq_cuentas a where a.cod_persona = gpcue.cod_persona
                                                  and   a.cod_paquete = gpcue.cod_paquete
                                                  and   a.nro_secuencia = gpcue.nro_secuencia
                                                  and   a.cod_modalidad = 41) cuenta_corriente,
       (select b.nro_cuenta from ge_paq_cuentas b where b.cod_persona = gpcue.cod_persona
                                                  and   b.cod_paquete = gpcue.cod_paquete
                                                  and   b.nro_secuencia = gpcue.nro_secuencia
                                                  and   b.cod_modalidad = 31) caja_ahorro,
       gpaq.cod_paquete cod_paquete, gpaq.descripcion descripcion_paquete,
       gcli.cod_oficina cod_oficina, gcli.cod_usu_oficial cod_usu_oficial
       from ge_clientes gcli, ge_paquetes gpaq, ge_paq_clientes gpcli, ge_paq_cuentas gpcue
       where gcli.cod_persona = gpcli.cod_persona
       and   gpaq.cod_paquete = gpcli.cod_paquete
       and   gpcli.cod_paquete = gpcue.cod_paquete
       and   gpcli.cod_persona = gpcue.cod_persona
       and   gpcli.nro_secuencia = gpcue.nro_secuencia
       and   gpcli.cod_paquete not in(select gpcue.cod_paquete from ge_paq_cuentas gpcue
                                      where gpcli.cod_paquete = gpcue.cod_paquete
                                      and   gpcli.cod_persona = gpcue.cod_persona
                                      and   gpcli.nro_secuencia = gpcue.nro_secuencia
                                      and   gpcue.cod_modulo = 5)
     group by gcli.cod_persona, gcli.cod_persona, gpcli.fec_inicio,
     gpaq.cod_paquete, gpaq.descripcion ,gpcue.cod_persona,gpcue.cod_paquete, gcli.cod_oficina, gcli.cod_usu_oficial,gpcue.nro_secuencia
     order by cod_usu_oficial, cod_oficina;

