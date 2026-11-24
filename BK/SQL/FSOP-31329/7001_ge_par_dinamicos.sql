begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ge_par_dinamicos(PARAMETRO,
                        VAL_PARAMETRO,
                        COD_MODULO,
                        COD_MODALIDAD,
                        COD_OFICINA,
                        COD_MONEDA,
                        COD_SUB_MODALIDAD) values('SNP_HAB_AWS',
                                                  'N',
                                                  null,
                                                  null,
                                                  null,
                                                  null,
                                                  null);
COMMIT;
