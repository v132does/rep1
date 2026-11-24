CREATE OR REPLACE PACKAGE IT.pag_otr IS
  v_cta_ori_invalido ge_dna_log_ord_tra.cod_error%type := 10;
  v_cta_cancelada  ge_dna_log_ord_tra.cod_error%type := 21;
  v_fon_insuficiente ge_dna_log_ord_tra.cod_error%type := 22;
  v_cta_des_invalido ge_dna_log_ord_tra.cod_error%type := 11;
  v_ord_tra_inexistente ge_dna_log_ord_tra.cod_error%type := 5;
  v_otr_error ge_dna_log_ord_tra.cod_error%type := 3;
  v_reg_correcto ge_dna_log_ord_tra.cod_error%type := 1;
  v_nro_ord_dup  ge_dna_log_ord_tra.cod_error%type := 4;
  v_tra_completada ge_dna_ord_transferencias_det.cod_retorno%type := 0;
  v_tra_proceso    ge_dna_ord_transferencias_det.cod_retorno%type := 13;
  v_tra_pendiente  ge_dna_ord_transferencias_det.cod_retorno%type := 26;
  v_tra_enviado    ge_dna_ord_transferencias_det.cod_retorno%type := 29;
  v_tra_rechazado  ge_dna_ord_transferencias_det.cod_retorno%type := 27;
  v_tra_anulado    ge_dna_ord_transferencias_det.cod_retorno%type := 28;


  procedure pr_obt_val_cuenta(p_nro_cuenta ge_cuentas.nro_cuenta%type,
                              p_cod_modulo out ba_modulos.cod_modulo%type,
                              p_cod_modalidad out ge_modalidades.cod_modalidad%type,
                              p_cod_moneda out ba_monedas.cod_moneda%type,
                              p_cod_error out number);

  function fu_val_ord_transferencia_det(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type) return number;

  procedure pr_obt_nro_cta_beneficiario (p_cod_banco ge_dna_ord_transferencias_det.cod_banco%type, p_nro_cuenta ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                         p_nro_cta_beneficiario out ge_dna_ord_transferencias_det.nro_cta_beneficiario%type, p_nro_cta_extracto out varchar2);


  procedure pr_ins_log_err_ord_tra (p_nro_ord_transferencia in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                    p_nro_cuenta in varchar2,
                                    p_cod_error in number, p_det_error varchar2);

  function fu_gen_ord_transferencia(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                    p_fecha in date,
                                    p_nro_cta_solicitante in ge_dna_ord_transferencias.nro_cta_solicitante%type,
                                    p_detalle     IN TYP_LISTADETALLEORDTRA,
                                    p_firmante    IN TYP_LISTAFIRMANTEORDTRA,
                                    p_dat_xml in ge_dna_ord_transferencias.dat_xml%type) return number;

  function fu_ins_ord_transferencia_det(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                        p_nro_item ge_dna_ord_transferencias_det.nro_item%type,
                                        p_nro_cta_beneficiario in ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                        p_denominacion in ge_dna_ord_transferencias_det.denominacion%type,
                                        p_cod_banco in ge_dna_ord_transferencias_det.cod_banco%type,
                                        p_monto in ge_dna_ord_transferencias_det.monto%type) return number;

  function fu_ins_ord_tra_firmantes (p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                      p_nombre in ge_dna_ord_tra_firmantes.nombre%type) return number;

  procedure pr_act_est_ord_transferencia(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                        p_nro_cta_beneficiario in ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                        p_estado in ge_dna_ord_transferencias_det.estado%type);

  procedure pr_act_nro_referencia (p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                   p_nro_cta_beneficiario in ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                   p_nro_referencia in ge_dna_ord_transferencias_det.nro_referencia%type);

  procedure pr_gen_not_ord_tra (p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type);

  function fu_obt_bancos return typ_listabancos;

  procedure pr_obt_dat_transferencia (p_nro_ord_transferencia ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                      p_cod_res_cab out ge_dna_ord_transferencias_det.cod_banco%type, p_des_res_cab out varchar2,
                                      p_item out typ_listaitemordtra);

  function fu_gen_snp_transferencias (p_nro_ord_transferencia ge_dna_ord_transferencias.nro_ord_transferencia%type) return number;

  procedure pr_gen_dat_ext_aduana (p_nro_cuenta ge_cuentas.nro_cuenta%type default '1101700874', p_fec_movimiento date default null);

  procedure pr_gen_ext_dna_xml(p_cod_extracto ge_dna_extractos.cod_extracto%type default null, p_nro_cuenta ge_cuentas.nro_cuenta%type default '1101700874', p_fec_movimiento date default null, p_ext_xml out clob );

  procedure pr_obt_ext_pendientes(p_typ_ext_xml out typ_listaextdnaxml);

  procedure pr_act_est_extracto(p_fec_extracto ge_dna_extractos.fecha%type, p_nro_cuenta ge_dna_extractos.nro_cuenta%type, p_cod_retorno ge_dna_extractos.cod_retorno%type, p_msj_retorno ge_dna_extractos.msj_retorno%type);

end;
/

