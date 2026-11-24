CREATE OR REPLACE PACKAGE IT.PAG_SIG IS
  -- Author  : Lic. Julio Cesar Leguizamon Gonzalez
  -- Created : 13/03/2007 01:45:43 p.m.
  -- Purpose : Interface Sistema de Informacion Gerencial
  PROCEDURE lp_balance_consolidado_mensual;
  PROCEDURE lp_balance_x_sucursal_mensual;
  PROCEDURE lp_bienes_adjudicados;
  PROCEDURE lp_cajas_de_seguridad;
  PROCEDURE lp_ciudades;
  PROCEDURE lp_comercio_exterior;
  PROCEDURE lp_cotizaciones;
  PROCEDURE lp_cuentas;
  PROCEDURE lp_cuentas_corrientes;
  PROCEDURE lp_cuotas_de_cajas_seg;
  PROCEDURE lp_departamentos;
  PROCEDURE lp_ge_gru_economicos;
  PROCEDURE lp_logros_x_oficial;
  PROCEDURE lp_logros_x_oficial_sgt;
  PROCEDURE lp_metas_x_oficial;
  PROCEDURE lp_monedas;
  PROCEDURE lp_motivos_de_bloqueo;
  PROCEDURE lp_oficiales;
  PROCEDURE lp_operaciones_morosas;
  PROCEDURE lp_operaciones_vencidas;
  PROCEDURE lp_balance_contable;
  PROCEDURE lp_his_balance_contable;
  PROCEDURE lp_sal_contables;
END PAG_SIG;
/

