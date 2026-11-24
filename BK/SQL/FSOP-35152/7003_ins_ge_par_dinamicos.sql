begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_parametros (parametro,
                           descripcion,
                           tab_relacion,
                           observacion,
                           modificable)
              values       ('COD_CAU_CTA_CANCEL',
                            'Codigo de causa de cancelacion',
                            'GE_PAR_DINAMICOS',
                            'Codigo de causa de cancelacion para devolucion de cheques',
                            'N');
commit;
insert into ge_parametros (parametro,
                           descripcion,
                           tab_relacion,
                           observacion,
                           modificable)
              values       ('COD_CAU_ORD_NO_PAGO',
                            'Codigo de causa de Orden de no Pago',
                            'GE_PAR_DINAMICOS',
                            'Codigo de causa de Orden de No Pago para devolucion de cheques',
                            'N');
commit;

insert into ge_par_dinamicos (parametro,
                              val_parametro)
             values           ('COD_CAU_CTA_CANCEL',
                              '107');
commit;
insert into ge_par_dinamicos (parametro,
                              val_parametro)
             values           ('COD_CAU_ORD_NO_PAGO',
                              '128');
commit;
