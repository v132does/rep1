create or replace package it.pap_fpy is


FUNCTION fu_obt_mto_fac_anual(p_cod_persona in varchar2,
                              p_mensaje in out varchar2) return number;

--
FUNCTION fu_val_mto_sol_credito(p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                                p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type,
                                p_monto in pr_solicitudes.monto%type,
                                p_tip_valor in varchar2) return boolean;
---
FUNCTION fu_val_facturacion(p_cod_persona in pr_solicitudes.cod_persona%type,
                            p_cod_moneda in pr_solicitudes.cod_moneda%type,
                            p_monto in pr_solicitudes.monto%type,
                            p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                            p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type) return varchar2;
---
FUNCTION fu_val_destino(p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                        p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type,
                        p_cod_destino in pr_solicitudes.Cod_Destino%type) return varchar2;

---
FUNCTION fu_val_mto_gar_cobertura(p_cod_persona in pr_solicitudes.cod_persona%type,
                                  p_cod_moneda in pr_solicitudes.cod_moneda%type,
                                  p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                                  p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type,
                                  p_mto_credito pr_solicitudes.monto%type,
                                  p_mto_garantia pr_garantias.mto_aplicado%type) return varchar2;
---
FUNCTION fu_obt_mto_car_mensual (p_nro_solicitud         pr_solicitudes.nro_solicitud%TYPE,
                                 p_nro_cuota              pr_sol_cuotas.nro_cuota%type,
                                 p_val_tas_comision       pr_sol_cargos.val_tasa%type,
                                 p_tipo                   varchar2) RETURN NUMBER;

end pap_fpy;
/

