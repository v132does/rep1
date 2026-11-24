create or replace package it.pag_app is

  v_es_nocturno   varchar2(1) := 'N';
  v_fec_sistema   DATE;
  v_pro_correcto  number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
  v_err_sql       number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;

  procedure pr_gen_rev_operaciones(p_referencia in varchar2,
                                   p_cod_error  out number,
                                   p_msj_error  out varchar2);

  procedure pr_gen_pag_servicio(p_cod_persona     in varchar2,
                                p_nro_cuenta      in varchar2,
                                p_cod_empresa     in number,
                                p_cod_servicio    in number,
                                p_tip_operacion   in varchar2,
                                p_monto           in float,
                                p_moneda          in varchar2,
                                p_nom_comercial   in varchar2,
                                p_referencia      in varchar2,
                                p_nro_transaccion out varchar2,
                                p_fec_transaccion out date,
                                p_error           out number,
                                p_respuesta       out varchar2,
                                p_codigoCanal     in varchar2 default null,
                                p_canal           in varchar2 default null,
                                p_cod_per_empresa in varchar2 default null,
                                p_cod_pag_servicio in varchar2 default null);
                                  
  procedure pr_gen_pag_servicio_canal(p_cod_persona     in varchar2,
                                      p_nro_cuenta      in varchar2,
                                      p_cod_empresa     in number,
                                      p_cod_servicio    in number,
                                      p_tip_operacion   in varchar2,
                                      p_monto           in float,
                                      p_moneda          in varchar2,
                                      p_nom_comercial   in varchar2,
                                      p_referencia      in varchar2,
                                      p_nro_transaccion out varchar2,
                                      p_fec_transaccion out date,
                                      p_error           out number,
                                      p_respuesta       out varchar2,
                                      p_codigoCanal     in varchar2 default null,
                                      p_canal           in varchar2 default null,
                                      p_cod_per_empresa in varchar2 default null,
                                      p_cod_pag_servicio in varchar2 default null);

   FUNCTION fu_obt_movimientos(p_nro_cuenta IN VARCHAR2,
                               p_fecha IN DATE DEFAULT NULL)
                               RETURN typ_datosCuenta;

   FUNCTION fu_obt_mov_hora(p_nro_cuenta IN VARCHAR2,
                            p_fec_inicial IN DATE DEFAULT NULL,
                            p_fec_final IN DATE DEFAULT NULL,
                            p_ini_hora IN VARCHAR2,
                            p_fin_hora IN VARCHAR2,
                            p_nro_pagina IN NUMBER DEFAULT NULL,
                            p_can_reg_pagina IN NUMBER DEFAULT NULL)
                            RETURN typ_datosCuenta;
end pag_app;
/
