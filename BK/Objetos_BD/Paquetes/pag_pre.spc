CREATE OR REPLACE PACKAGE IT.PAG_PRE is
    
  ---- Author  : XPY0035
  -- Created : 07/05/2015 10:13:05 a.m.
  -- Purpose : validaciones para productos preaprobados
   -- para parseo XML (segun operacion)
  TYPE tp_datosCuota IS RECORD(   
      plazo12       ge_pro_pre_aprobados.plz_12_meses%type,
      plazo18       ge_pro_pre_aprobados.plz_18_meses%type,
      plazo24       ge_pro_pre_aprobados.plz_24_meses%type,
      plazo30       ge_pro_pre_aprobados.plz_30_meses%type,
      plazo36       ge_pro_pre_aprobados.plz_36_meses%type,
      plazo42       ge_pro_pre_aprobados.plz_42_meses%type,
      plazo48       ge_pro_pre_aprobados.plz_48_meses%type,
      plazo54       ge_pro_pre_aprobados.plz_54_meses%type,
      plazo60       ge_pro_pre_aprobados.plz_60_meses%type,
      montoMaximo   ge_pro_pre_aprobados.max_monto%type,
      montoMinimo   ge_pro_pre_aprobados.min_monto%type,
      plazoMaximo   ge_pro_pre_aprobados.max_plazo%type,
      plazoMinimo   ge_pro_pre_aprobados.min_plazo%type,
      montoMaxCuota     ge_pro_pre_aprobados.mto_max_cuota%type,
      CodSubModalidad   ge_pro_pre_aprobados.cod_sub_modalidad%type -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core	-- 10/2016 --
  );
  TYPE tp_datosSeguro IS RECORD(
     codigoSeguro   ge_tip_seguros.cod_tipo%type,
     texto          ge_det_seguros.texto%type,
     montoAsegurado ge_det_seguros.mto_asegurado%type,
     montoCuota     ge_det_seguros.mto_cuota%type,
     codigoEnte     ge_tip_seguros.cod_ente%type,
     nombreEnte     varchar2(60)     
  );
   TYPE tp_lista_seguros IS TABLE OF tp_datosSeguro INDEX BY BINARY_INTEGER;
   -- cursor para reutilizar datos de simulacion de cuotas
  CURSOR gc_sim_cuotas(p_nro_simulacion IN pr_simulaciones.nro_simulacion%TYPE) IS
     SELECT nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) mto_cuota, c.*
       FROM pr_sim_cuotas c
      WHERE c.nro_simulacion = p_nro_simulacion
        AND c.nro_cuota > 0;
  -- cursor para reutilizar datos de cargos
  CURSOR gc_sim_cargos(p_nro_simulacion IN pr_simulaciones.nro_simulacion%TYPE) IS
     SELECT rownum nro, t.descripcion cargo, e.descripcion seguro, round(c.val_tasa, 2) tasa, c.monto importe
       FROM pr_sim_cargos c, ge_transacciones t, ge_entes e, pr_simulaciones sim
      WHERE c.nro_simulacion = p_nro_simulacion
        AND sim.nro_simulacion = p_nro_simulacion
        AND c.cod_transaccion = t.cod_transaccion
        AND c.cod_transaccion <> 1521
        AND t.cod_modulo = sim.cod_modulo
        AND t.cod_modalidad = sim.cod_modalidad
        AND e.cod_ente(+) = c.cod_ent_seguro
        AND c.monto > 0;
  -- Indica si una persona tiene un prestamo preaprobado
  function fu_tie_pre_aprobado(p_cod_persona   in ge_pro_pre_aprobados.cod_persona%type,
                               p_cod_modulo    in ge_pro_pre_aprobados.cod_modulo%type,
                               p_cod_modalidad in ge_pro_pre_aprobados.cod_modalidad%type,
                               p_ind_atm       in varchar2,
                               p_datos         out tp_datosCuota) return number;

                               
  -- obtiene el codigo de modalidad de tarjeta a partir de afinidad y sub_afinidad
  function fu_obt_mad_tarjeta(p_afinidad     in ta_tipos.afinidad%type,
                              p_sub_afinidad in ta_tipos.sub_afinidad%type) return number;
                              
  -- obtiene datos de afinidad de una tarjeta segun referencia general
  procedure pr_obt_tar_afinidad(p_val_maximo   IN ba_cod_referencias.val_maximo%type,
                                p_abreviatura  IN ba_cod_referencias.abreviatura%type,
                                p_afinidad     OUT ba_cod_referencias.val_minimo%type,
                                p_sub_afinidad OUT ba_cod_referencias.val_minimo%type,
                                p_significado  OUT ba_cod_referencias.significado%type);
                                
  -- indica si una persona tiene una tarjeta preaprobada                             
  function fu_tie_tar_aprobada(p_cod_persona  in ba_personas.cod_persona%type,
                               p_lin_aprobada out ge_cli_aprobados_atm_tmp.lin_aprobada%TYPE,
                               p_afinidad     out ge_cli_aprobados_atm_tmp.afinidad%type,
                               p_sub_afinidad out ge_cli_aprobados_atm_tmp.clase%type,
                               p_moneda       out ba_monedas.cod_moneda%TYPE) return number;
  
  -- Obtiene el numero de simulacion generado para el producto 
  function fu_obt_nro_simulacion(p_cod_persona   in ba_personas.cod_persona%type,
                                 p_cod_modulo    in pr_simulaciones.cod_modulo%type,
                                 p_cod_modalidad in pr_simulaciones.cod_modalidad%type,
                                 p_monto         in pr_simulaciones.monto%type,
                                 p_cuotas        in pr_simulaciones.can_cuotas%type default null)
    return number;
  
  -- Obtiene los datos de simulacion del producto preaprobado
  procedure pr_obt_dat_simulacion(p_nro_simulacion in pr_simulaciones.nro_simulacion%type,
                                  p_monto         out pr_simulaciones.monto%type,
                                  p_plazo         out pr_simulaciones.can_cuotas%type,
                                  p_cuota         out pr_simulaciones.monto%type,
                                  p_cod_moneda    out pr_simulaciones.cod_moneda%type,
                                  p_val_tasa      out pr_simulaciones.val_tasa%type,
                                  p_fec_pri_venc  out pr_simulaciones.fec_pri_vencimiento%type,                                  
                                  p_tas_des_com   out pr_simulaciones.tot_interes%type,
                                  p_fec_inicio    out pr_simulaciones.fec_inicio%type,
                                  p_cotizacion    out pr_simulaciones.cotizacion%type,
                                  p_tot_interes   out pr_simulaciones.tot_interes%type,
                                  p_tot_cargos    out pr_simulaciones.tot_cargos%type,
                                  p_tip_monto     out varchar2,
                                  p_mto_edilicio  out pr_simulaciones.mto_edilicio%type,
                                  p_tip_interes   out ba_cod_referencias.significado%type);

  -- Indica si una persona es cliente nomina                                  
  function fu_es_cli_nomina(p_cod_persona in ba_personas.cod_persona%type) return varchar2;
  
  -- Indica si una cuenta es cuenta nomina 
  function fu_es_cta_nomina(p_cod_persona in ba_personas.cod_persona%type,
                            p_nro_cuenta  in ge_cuentas.nro_cuenta%type,
                            p_cod_modalidad  in ge_cuentas.cod_modalidad%type) return varchar2; 
  
  -- funcion para obtener tasa de seguro de vida
  function fu_obt_tas_seg_vida(p_cod_modalidad in ge_modalidades.cod_modalidad%type,
                               p_cod_moneda    in ba_monedas.cod_moneda%type default null,
                               p_monto         in ge_movimientos.monto%type default null) return number;
  
  -- obtiene los cargos de una simulacion                             
  procedure pr_obt_sim_cargos(p_nro_simulacion   in pr_simulaciones.nro_simulacion%type,
                              p_des_mto_comision out pr_sim_cargos.monto%type,
                              p_tas_impuesto     out pr_sim_cargos.val_tasa%type);
  
  -- obtiene la tasa maxima de un plazo (p_plazo en meses)  
  function fu_obt_tas_interes(p_cod_moneda    in ba_monedas.cod_moneda%type,
                              p_cod_modalidad in ge_pro_pre_aprobados.cod_modalidad%type,
                              p_plazo         in ge_pro_pre_aprobados.max_plazo%type,
                              p_cod_sub_modalidad in ge_pro_pre_aprobados.cod_sub_modalidad%type default null -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core	-- 10/2016 -- 
                              ) return number;
  
  -- obtiene la tasa y descripcion de una tarjeta preaprobada
  procedure pr_obt_tar_nom_tasa(p_cod_modalidad in ge_modalidades.cod_modalidad%type,
                                p_afinidad      in out varchar2,
                                p_sub_afinidad  in varchar2,
                                p_val_tasa      out ta_cta_tarjetas.tas_int_compra%type,
                                p_nombre        out ge_modalidades.descripcion%type);
                                
  -- si se puede ofertar adelanto tarjeta
  function fu_obt_tar_adelanto(p_cod_persona in ba_personas.cod_persona%type,
                               p_cod_moneda  out ba_monedas.cod_moneda%type,
                               p_monto       out number) return varchar2;
                               
   --obtener la cantidad de días transcurridos desde la fecha de ultima apertura de cuenta de TC hasta la fecha --
  function fu_obt_can_dia_tarjeta( p_cod_persona in ba_personas.cod_persona%type ) return number;
  
  -- obtener cantidad de solicitudes de tarjetas
  function fu_obt_tar_can_solicitudes( p_cod_persona  in ba_personas.cod_persona%type ) return number;
  
  -- Indica si una persona tiene seguro para ofrecer
  function fu_tie_seguro(p_cod_persona in ba_personas.cod_persona%type,
                         p_datos       out tp_datosSeguro) return number;
  -- Indica si una persona tiene seguro para ofrecer en HomeBanking
  function fu_tie_seguro_hb(p_cod_persona in ba_personas.cod_persona%type,
                         p_lista      out tp_lista_seguros,
                         p_codigoCanal in  VARCHAR2) return number;
  -- obtiene el monto del cargo de una cuota de prestamo preaprobado
  function fu_obt_mto_cargo(p_nro_simulacion in pr_sim_cuotas.nro_simulacion%type,
                            p_nro_cuota      in pr_sim_cuotas.nro_cuota%type) return number;
 
end PAG_PRE;
/

