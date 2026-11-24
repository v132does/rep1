create or replace package it.pag_swe is

  -- Author  : ITTI
  -- Created : 22/2/2023 11:49:59
  -- Purpose : Registrar Pagos de Servicios de Wepa 

  --pago de servicios cnb wepa
  procedure pr_gen_pag_ser_cnb(p_cod_ente                in varchar2,
                               p_cod_servicio            in number,
                               p_descripcion             in varchar2,
                               p_monto                   in number,
                               p_cod_moneda              in varchar2,
                               p_cod_transaccion_wepa    in varchar2,
                               p_cod_transaccion_bancard in varchar2,
                               p_error                   out number,
                               p_respuesta               out varchar2);
  --liquidacion pago de servicios wepa                             
  procedure pr_pro_liq_cnb;

end pag_swe;
/

