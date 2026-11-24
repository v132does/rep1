begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

alter table it.sb_lcr_liq_inv_tmp add  (fecha date,
                                        cod_persona varchar2(10),
                                        tipo  varchar2(1),
                                        deposito  number(1),
                                        saldo_total number(18,2),
                                        sal_vista_gs  number(18,2),
                                        sal_vista_ext number(18,2),
                                        sal_plazo_gs  number(18,2),
                                        sal_plazo_ext number(18,2),
                                        sal_res_gs  number(18,2),
                                        sal_res_ext number(18,2));
commit;
