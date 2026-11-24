create or replace procedure it.prg_con_verificaciones is
  PROCEDURE lp_cuentas_sin_cli_ppal;  	 		 --1
  PROCEDURE lp_ahv;        				 		       --2
  PROCEDURE lp_con_retenciones;       	 		 --3
  PROCEDURE lp_con_cj_movimientos;       		 --5
  PROCEDURE lp_con_cli_nex_ge_clientes;  		 --6
  PROCEDURE lp_cuentas_varios_cli_ppal;  		 --8
  PROCEDURE lp_ahv_dias_sal_mensuales;   		 --9
  PROCEDURE lp_con_cuentas_clientes;     		 --10
  PROCEDURE lp_con_ge_cuentas;           		 --11
  PROCEDURE lp_con_ge_movimientos;       		 --12
  PROCEDURE lp_con_mae_ge_cuentas;       		 --13
  PROCEDURE lp_con_ofi_ge_movimientos;   		 --14
  PROCEDURE lp_ope_sin_garantias;   		 	   --15
  PROCEDURE lp_con_promotores;           		 --16
  PROCEDURE lp_cda_con_saldos;           		 --17
  PROCEDURE lp_ahv_saldos_vistas;        		 --18
  PROCEDURE lp_con_sal_mensuales;        		 --19
  PROCEDURE lp_con_tip_asientos;         		 --21
  PROCEDURE lp_cda_con_estado_incorrecto;		 --22
  PROCEDURE lp_cda_con_estado_vencido;   		 --23
  PROCEDURE lp_con_dir_duplicado;        		 --24
  PROCEDURE lp_con_extracto;             		 --25
  PROCEDURE lp_cda_sin_cupones;          		 --26
  PROCEDURE lp_con_tas_personalizada;    		 --28
  PROCEDURE lp_con_ge_tas_fechas;        		 --29
  PROCEDURE lp_ahv_con_firmas;           		 --30
  PROCEDURE lp_ahv_con_firmantes;        		 --31
  PROCEDURE lp_ctacte_con_firmas;        		 --32
  PROCEDURE lp_con_cta_inexistentes;     		 --33
  PROCEDURE lp_con_rel_inexistentes;     		 --34
  PROCEDURE lp_con_dif_firmante4;        		 --38
  PROCEDURE lp_cda_cupon_monto_cero;     		 --39
  PROCEDURE lp_cda_cupon_pagado_sin_fecha;   --41
  PROCEDURE lp_cda_saldo_menor_capital;  		 --42
  PROCEDURE lp_cda_serie_desconocida; 	 		 --43
  PROCEDURE lp_cda_saldo_sin_interes; 	     --44
  PROCEDURE lp_cda_nro_invalido; 				     --45
  PROCEDURE lp_cda_fecha_apertura; 			 	   --46
  PROCEDURE lp_cda_sin_beneficiario; 		 	   --47
  PROCEDURE lp_cda_ult_vcto_cupon; 		 		   --48
  PROCEDURE lp_cda_con_estado_incorrecto2;   --49
  PROCEDURE lp_ptmo_con_estado_incorrecto; 	 --50
  PROCEDURE lp_ptmo_Inicio; 	 					     --51
  PROCEDURE lp_ptmo_devengado_cuotas;			   --52
  PROCEDURE lp_ptmo_cartera;				 		     --53
  PROCEDURE lp_ptmo_adelantado;				 	     --54
  PROCEDURE lp_ptmo_no_adelantado;		 		   --55
  PROCEDURE lp_ptmo_adevengar_cuotas;	 		   --56
  PROCEDURE lp_ptmo_cuo_pago_anticipado;		 --57
  PROCEDURE lp_dif_garantia_detalle;		 	   --58
  PROCEDURE lp_gar_val_vta_rapida;		 	 	   --59

  PROCEDURE lp_che_ord_no_pagos;		 	 	     --60
  PROCEDURE lp_che_ord_no_pagos1;		 	 	     --61
  PROCEDURE lp_che_cert;		 	 	             --62
  PROCEDURE lp_che_cert1;		 	 	             --63
  PROCEDURE lp_che_anulados; 	 	             --64
  PROCEDURE lp_che_anulados1;	 	             --65
  PROCEDURE lp_che_pagados; 	 	             --66
  PROCEDURE lp_che_pagados1;	 	             --67
  PROCEDURE lp_chequera;	 	                 --68
  PROCEDURE lp_chequera1;	 	                 --69
  PROCEDURE lp_che_ventanilla;	 	           --70
  PROCEDURE lp_che_gerencia;	 	             --71
  
  PROCEDURE lp_tar_sin_relacion;             --72
  PROCEDURE lp_tar_mas_vigente;	 	           --73
  PROCEDURE lp_tar_sin_vigente;	             --74
  
    
-- Cuentas Sin Cliente Principal...............................................................1
procedure lp_cuentas_sin_cli_ppal is
  Cursor Cuentas is
   select a.nro_cuenta, 'Ahorro Vista '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from ah_cta_vistas a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Certificado de Ahorro '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from ah_cta_certificados a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Prestamo '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'N','CANCELADO','ACTIVO') estado
   from pr_cta_prestamos a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Cuenta Corriente '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from cc_cta_corrientes a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Cuenta Bancaria '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from cc_cta_bancarias a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Tarjeta '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from ta_cta_tarjetas a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Importacion '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from CX_cta_importaciones a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Exportacion '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from cx_cta_exportaciones a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Fianza '||lpad(trim(a.nro_cuenta),15,0)||' No tiene cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from CX_fianzas a, ge_cuentas g
   where not exists (select 1 from ge_cta_clientes b
                     where b.nro_cuenta = a.nro_cuenta
                     and b.relacion = 'P')
	and a.nro_cuenta = g.nro_cuenta;
begin
  For reg in Cuentas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion,
										estado)
                      values (reg.nro_cuenta,
                              1,
                              reg.detalle,
										reg.estado);
  End loop;
end lp_cuentas_sin_cli_ppal;

-- Inconsistencia en AH_CTA_VISTAS.............................................................2
procedure lp_ahv is
  Cursor Vistas is
  select nro_cuenta
    from ah_cta_vistas a
   where (a.estado in ('C','A') -- cancelados o nuevos con saldos
          and (nvl(a.sal_total,0) <> 0
          or nvl(a.sal_retenido,0) <> 0
          or nvl(a.sal_bloqueado,0) <> 0))
   or   (nvl(fug_obt_val_tasa(cod_modulo,
                        cod_modalidad,
                        cod_oficina,
                        nro_cuenta,
                        cod_moneda,
                        sal_total,
                        tas_personalizada,
                        cod_tasa,
                        null,
                        sysdate),0) < 0)
   or (sal_total - sal_retenido -  sal_bloqueado < 0);
begin
  For reg in Vistas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              2,
                              'AHV Inconsistencia de datos en AH_CTA_VISTAS');
  End loop;
end lp_ahv;

-- Inconsistencia en AH_RETENCIONES............................................................3
procedure lp_con_retenciones is
  Cursor Retenciones is
  select nro_cuenta
    from ah_cta_vistas a
   where a.sal_retenido <> (select NVL(sum(B.SAL_RETENIDO),0) --Se modifico para que sume el campo SAL_RETENIDO en vez de MONTO <<EF,08/09/2009>>
                              from ah_retenciones b
                             where a.nro_cuenta = b.nro_cuenta
                               and a.cod_modulo = b.cod_modulo
                               and a.cod_modalidad = b.cod_modalidad
                               and a.cod_oficina = b.cod_oficina
                               and a.cod_moneda = b.cod_moneda
                               and b.liberado = 'N')
union
  select nro_cuenta
    from cc_cta_corrientes a
   where a.sal_retenido <> (select NVL(sum(B.SAL_RETENIDO),0) --Se modifico para que sume el campo SAL_RETENIDO en vez de MONTO <<EF,08/09/2009>>
                              from ah_retenciones b
                             where a.nro_cuenta = b.nro_cuenta
                               and a.cod_modulo = b.cod_modulo
                               and a.cod_modalidad = b.cod_modalidad
                               and a.cod_oficina = b.cod_oficina
                               and a.cod_moneda = b.cod_moneda
                               and b.liberado = 'N');
begin
  For reg in Retenciones loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              3,
                              'Inconsistencia de datos entre AH_CTA_VISTAS y AH_RETENCIONES');
  End loop;
end lp_con_retenciones;

-- Inconsistencia en CJ_MOVIMIENTOS............................................................5
procedure lp_con_cj_movimientos is
  Cursor Caja is
  select nro_cuenta
    from cj_movimientos a
   where estado = 'N'
     and cod_tra_padre not in (201,202,203,240,355)
     and not exists (select 0 from ge_movimientos b
                      where a.cod_usuario = b.cod_usuario
                        and a.fecha = b.fecha
                        and a.hora = b.hora
                        and a.nro_cuenta = b.nro_cuenta
                        and a.cod_moneda = b.cod_moneda
                        and a.monto = b.monto
                        and a.cod_tra_padre = b.cod_tra_padre
                        and a.estado = 'N');
begin
  For reg in Caja loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              5,
                              'Inconsistencia de datos entre CJ_MOVIMIENTOS y GE_MOVIMIENTOS');
  End loop;
end lp_con_cj_movimientos;

-- Clientes que no existen en GE_CLIENTES......................................................6
procedure lp_con_cli_nex_ge_clientes is
  Cursor Clientes is
  select nro_cuenta
    from ge_cta_clientes a, ba_personas x, ge_clientes z
   where a.relacion = 'P'
     and not exists (select 1 from ge_clientes x
                     where x.cod_persona = a.cod_persona)
     and x.cod_persona = a.cod_persona
     and z.cod_persona(+) = a.cod_persona;
begin
  For reg in Clientes loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              6,
                              'Cuenta de cliente que no figura en ge_clientes');
  End loop;
end lp_con_cli_nex_ge_clientes;


-- Cuentas con varios clientes ppales..........................................................8
procedure lp_cuentas_varios_cli_ppal is
  Cursor Cuentas is
   select a.nro_cuenta, 'Ahorro Vista '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from ah_cta_vistas a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Certificado de Ahorro '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from ah_cta_certificados a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Prestamo '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'N','CANCELADO','ACTIVO') estado
   from pr_cta_prestamos a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Cuenta Corriente '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from cc_cta_corrientes a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Cuenta Bancaria '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from cc_cta_bancarias a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Tarjeta '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from ta_cta_tarjetas a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Importacion '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from CX_cta_importaciones a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Exportacion '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from CX_cta_exportaciones a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta
   union all
   select a.nro_cuenta, 'Fianza '||lpad(trim(a.nro_cuenta),15,0)||' Tiene mas de 1 Cliente Principal en GE_CTA_CLIENTES' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from CX_fianzas a, ge_cuentas g
   where exists (select nro_cuenta
                  from ge_cta_clientes
                  where relacion = 'P'
						and nro_cuenta = a.nro_cuenta
                  group by nro_cuenta
                  having count(*)>1)
	and a.nro_cuenta = g.nro_cuenta;
begin
  For reg in Cuentas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion, estado)
                      values (reg.nro_cuenta,
                              8,
                              reg.detalle,
										reg.estado);
  End loop;
end lp_cuentas_varios_cli_ppal;

-- Inconsistencia en dias sal_mensuales........................................................9
procedure lp_ahv_dias_sal_mensuales is
  Cursor Sal_men is
  select b.nro_cuenta
    from ah_cta_vistas b,ah_sal_mensuales a
   where a.nro_cuenta = b.nro_cuenta
     and b.est_batch not in ('C','A','P')
     and a.ano = to_number(to_char(sysdate,'yyyy'))
     and a.mes = to_number(to_char(sysdate,'MM'))
     and a.can_dia_acumulado <> to_number(to_char(sysdate-1,'DD'))
     and (trunc(to_date('01'||to_char(sysdate,'mmyyyy'),'ddmmyyyy')) <> trunc(sysdate))
     and b.fec_cam_estado <= trunc(to_date('01'||to_char(sysdate,'mmyyyy'),'ddmmyyyy'))
   union
  select b.nro_cuenta
    from ah_cta_vistas b,ah_sal_mensuales a
   where a.nro_cuenta = b.nro_cuenta
     and b.est_batch not in ('C','A','P')
     and a.ano = to_number(to_char(sysdate,'yyyy'))
     and a.mes = to_number(to_char(sysdate,'MM'))
     and a.can_dia_acumulado <> (to_number(to_char(sysdate-1,'DD'))-to_number(to_char(b.fec_cam_estado-1,'DD')))
     and b.fec_cam_estado > trunc(to_date('01'||to_char(sysdate,'mmyyyy'),'ddmmyyyy'));
begin
  For reg in Sal_men loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              9,
                              'Inconsistencia en dias en AH_SAL_MENSUALES');
  End loop;
end lp_ahv_dias_sal_mensuales;

-- Inconsistencia en GE_CTA_VISTAS.............................................................10
procedure lp_con_cuentas_clientes is
  Cursor Clientes is
  select nro_cuenta
  from ge_cta_clientes a
  where exists (select 0 from ah_cta_vistas b
                 where b.nro_cuenta = a.nro_cuenta)
                   and not exists (select 0 from ah_cta_vistas b
                                    where a.nro_cuenta = b.nro_cuenta
                                      and a.cod_modulo = b.cod_modulo
                                      and a.cod_modalidad = b.cod_modalidad
                                      and a.cod_oficina = b.cod_oficina)
  union
  select nro_cuenta
  from ge_cta_clientes a
  where exists (select 0 from ah_cta_certificados b
                 where b.nro_cuenta = a.nro_cuenta)
                   and not exists (select 0 from ah_cta_certificados b
                                    where a.nro_cuenta = b.nro_cuenta
                                      and a.cod_modulo = b.cod_modulo
                                      and a.cod_modalidad = b.cod_modalidad
                                      and a.cod_oficina = b.cod_oficina)
  union
  select nro_cuenta
  from ge_cta_clientes a
  where exists (select 0 from cc_cta_corrientes b
                 where b.nro_cuenta = a.nro_cuenta)
                   and not exists (select 0 from cc_cta_corrientes b
                                    where a.nro_cuenta = b.nro_cuenta
                                      and a.cod_modulo = b.cod_modulo
                                      and a.cod_modalidad = b.cod_modalidad
                                      and a.cod_oficina = b.cod_oficina);

begin
  For reg in Clientes loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              10,
                              'Inconsistencia de datos entre ge_cta_clientes y el MAESTRO DE CUENTAS');
  End loop;
end lp_con_cuentas_clientes;

--Inconsistencia en GE_CUENTAS.................................................................11
procedure lp_con_ge_cuentas is
  Cursor  Cuentas  is
  select nro_cuenta
    from ge_cuentas a
   where exists (select 0 from ah_cta_vistas b
                  where b.nro_cuenta = a.nro_cuenta)
                    and not exists (select 0 from ah_cta_vistas b
                                    where a.nro_cuenta = b.nro_cuenta
                                      and a.cod_modulo = b.cod_modulo
                                      and a.cod_modalidad = b.cod_modalidad
                                      and a.cod_oficina = b.cod_oficina
                                      and a.cod_moneda = b.cod_moneda)
union
  select nro_cuenta
    from ge_cuentas a
   where exists (select 0 from cc_cta_corrientes b
                  where b.nro_cuenta = a.nro_cuenta)
                    and not exists (select 0 from cc_cta_corrientes b
                                    where a.nro_cuenta = b.nro_cuenta
                                      and a.cod_modulo = b.cod_modulo
                                      and a.cod_modalidad = b.cod_modalidad
                                      and a.cod_oficina = b.cod_oficina
                                      and a.cod_moneda = b.cod_moneda)
union
  select nro_cuenta
    from ge_cuentas a
   where exists (select 0 from ah_cta_certificados b
                  where b.nro_cuenta = a.nro_cuenta)
                    and not exists (select 0 from ah_cta_certificados b
                                    where a.nro_cuenta = b.nro_cuenta
                                      and a.cod_modulo = b.cod_modulo
                                      and a.cod_modalidad = b.cod_modalidad
                                      and a.cod_oficina = b.cod_oficina
                                      and a.cod_moneda = b.cod_moneda);
begin
  For reg in Cuentas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              11,
                              'Inconsistencia de datos entre GE_CUENTAS y MAESTRO DE CUENTAS');
  End loop;
end lp_con_ge_cuentas;

-- Inconsistencia en GE_MOVIMIENTOS............................................................12
procedure lp_con_ge_movimientos is
  Cursor Movim is
  select nro_cuenta
    from ge_movimientos a
   where exists (select 0 from ah_cta_vistas b
                  where b.nro_cuenta = a.nro_cuenta)
                    and not exists (select 0 from ah_cta_vistas b
                                     where a.nro_cuenta = b.nro_cuenta
                                       and a.cod_modulo = b.cod_modulo
                                       and a.cod_modalidad = b.cod_modalidad
                                       and a.cod_oficina = b.cod_oficina
                                       and a.cod_moneda = b.cod_moneda);
begin
  For reg in Movim loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              12,
                              'Inconsistencia de datos entre GE_MOVIMIENTOS y AH_CTA_VISTAS');
  End loop;
end lp_con_ge_movimientos;

-- Inconsistencia entre archivos maestros y GE_CUENTAS / GE_CTA_CLIENTES.......................13
procedure lp_con_mae_ge_cuentas is
  Cursor Cuentas is
   select nro_cuenta, 'Ahorro Vista '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from ah_cta_vistas a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Certificado de Ahorro '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from ah_cta_certificados a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Prestamo '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from pr_cta_prestamos a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Cuenta Corriente '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from cc_cta_corrientes a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Cuenta Bancaria '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from cc_cta_bancarias a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Tarjeta '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from ta_cta_tarjetas a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Importacion '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from CX_cta_importaciones a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Exportacion '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from CX_cta_exportaciones a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Fianza '||lpad(trim(cod_fianza),15,0)||' No existe en GE_CUENTAS' Detalle
   from CX_fianzas a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)
   union all
   select nro_cuenta, 'Cobranza '||lpad(trim(nro_cuenta),15,0)||' No existe en GE_CUENTAS' Detalle
   from Cx_Cta_Cobranzas a
   where not exists (select 1 from ge_cuentas b
                     where b.nro_cuenta = a.nro_cuenta)                     
	union all
   select nro_cuenta, 'Cuenta '||lpad(trim(nro_cuenta),15,0)||' Modulo '||cod_modulo||' Modalidad '||cod_modalidad||' en GE_CUENTAS No existe en MAESTRO' Detalle
   from  ge_cuentas a
   where not exists (select 1 from ah_cta_vistas b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from ah_cta_certificados b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from pr_cta_prestamos b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from cc_cta_corrientes b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from cc_cta_bancarias b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from ta_cta_tarjetas b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from CX_cta_importaciones b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from CX_cta_exportaciones b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from CX_fianzas b
                     where b.nro_cuenta = a.nro_cuenta)
  and not exists (select 1 from Cx_Cta_Cobranzas b
                     where b.nro_cuenta = a.nro_cuenta)    
  and not exists (select 1 from lc_cta_cambios b
                     where b.nro_cuenta = a.nro_cuenta)                         
  and not exists (select 1 from md_cta_documentos b
                     where b.nro_cuenta = a.nro_cuenta)    
   union all
   select nro_cuenta, 'Cuenta '||lpad(trim(nro_cuenta),15,0)||' Modulo '||cod_modulo||' Modalidad '||cod_modalidad||' en GE_CTA_CLIENTES No existe en MAESTRO' Detalle
   from  ge_cta_clientes a
   where not exists (select 1 from ah_cta_vistas b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from ah_cta_certificados b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from pr_cta_prestamos b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from cc_cta_corrientes b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from cc_cta_bancarias b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from ta_cta_tarjetas b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from CX_cta_importaciones b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from CX_cta_exportaciones b
                     where b.nro_cuenta = a.nro_cuenta)
	and not exists (select 1 from CX_fianzas b
                     where b.nro_cuenta = a.nro_cuenta)
  and not exists (select 1 from Cx_Cta_Cobranzas b
                     where b.nro_cuenta = a.nro_cuenta)
  and not exists (select 1 from Lc_Cta_Cambios b
                     where b.nro_cuenta = a.nro_cuenta)
  and not exists (select 1 from Md_Cta_Documentos b
                     where b.nro_cuenta = a.nro_cuenta);
begin
  For reg in Cuentas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              13,
                              reg.detalle);
  End loop;
end lp_con_mae_ge_cuentas;

-- Inconsistencia en oficina de GE_MOVIMIENTOS.................................................14
procedure lp_con_ofi_ge_movimientos is
  Cursor Oficinas is
  select nro_cuenta--'INCONSISTENCIA EN OFICINA DE GE_MOVIMIENTOS',count(*)
    from ge_movimientos a
   where exists (select 0
                   from ge_cta_clientes b
                  where b.nro_cuenta = a.nro_cuenta
                    and b.relacion = 'P'
                    and b.cod_oficina <> a.cod_oficina);
begin
  For reg in Oficinas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              14,
                              'Cuenta esta relacionada a of.distintas en GE_MOVIMIENTOS y ge_cta_clientes');
  End loop;
end lp_con_ofi_ge_movimientos;

-- Operaciones sin Garantias...................................................................15
procedure lp_ope_sin_garantias is
  Cursor Sin_Garantias is
   select p.nro_cuenta, 'Prestamo '||lpad(trim(p.nro_cuenta),15,0)||' No tiene garantia en PR_CTA_GARANTIAS' Detalle, decode(g.estado,'N','CANCELADO','ACTIVO') estado
   from pr_cta_prestamos p, ge_cuentas g
   where not exists (select 1 from pr_cta_garantias where nro_cuenta = p.nro_cuenta)
     and p.estado != 'N'
	and p.nro_cuenta = g.nro_cuenta
   union all
   select i.nro_cuenta, 'Importacion '||lpad(trim(i.nro_cuenta),15,0)||' No tiene garantia en CX_CTA_GARANTIAS' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from CX_cta_importaciones i, ge_cuentas g
   where not exists (select 1 from CX_cta_garantias where nro_cuenta = i.nro_cuenta)
	and i.nro_cuenta = g.nro_cuenta
   union all
   select f.nro_cuenta, 'Fianza '||lpad(trim(f.nro_cuenta),15,0)||' No tiene garantia en CX_CTA_GARANTIAS' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from CX_fianzas f, ge_cuentas g
   where not exists (select 1 from CX_cta_garantias where nro_cuenta = f.nro_cuenta)
	and f.nro_cuenta = g.nro_cuenta
   union all
   select t.nro_cuenta, 'Tarjeta '||lpad(trim(t.nro_cuenta),15,0)||' No tiene garantia en TA_CTA_GARANTIAS' Detalle, decode(g.estado,'C','CANCELADO','ACTIVO') estado
   from ta_cta_tarjetas t, ge_cuentas g
   where not exists (select 1 from ta_cta_garantias where nro_cuenta = t.nro_cuenta)
	and t.nro_cuenta = g.nro_cuenta;
begin
  For reg in Sin_Garantias loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion,
										estado)
                      values (reg.nro_cuenta,
                              15,
                              reg.detalle,
										reg.estado);
  End loop;
end lp_ope_sin_garantias;

-- Personas con promotores que ya no lo son....................................................16
procedure lp_con_promotores is
  Cursor  Promotores is
  SELECT cod_persona, cod_usu_promotor
  FROM BA_PERSONAS A
  WHERE EXISTS (SELECT 1 FROM BA_USUARIOS X
                  WHERE X.COD_USUARIO = A.COD_USU_PROMOTOR
                    AND X.PROMOTOR = 'N');
begin
  For reg in Promotores loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.cod_persona,
                              16,
                              'Cod_Persona '||reg.cod_persona||' con promotor '||reg.cod_usu_promotor||' que ya no lo es');
  End loop;
end lp_con_promotores;

-- Saldos con movimientos CDA..................................................................17
procedure lp_cda_con_saldos is
  Cursor Saldos is
  select nro_cuenta, sal_tot_batch, sal_total, m_monto
  from ah_cta_certificados x,
  (select nro_cuenta m_nro_cuenta,
        sum(decode(a.cod_transaccion, 515, 0, decode(tipo,'D',monto * -1, monto))) m_monto
   from ge_transacciones b,ge_movimientos a
  where nro_cuenta is not null
    and estado = 'N'
    and reversado = 'N'
    and monto <> 0
    and b.cod_modulo = a.cod_modulo
    and b.cod_modalidad = a.cod_modalidad
    and b.cod_transaccion = a.cod_transaccion
    and b.afecta <> 'N'
  group by nro_cuenta)
  where x.nro_cuenta = m_nro_cuenta
    and sal_tot_batch + m_monto <> sal_total;
begin
  For reg in Saldos loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              17,
                              'CDA SALDO CON MOVIMIENTOS '||reg.nro_cuenta||
                              ' SAL BATCH '||to_char(reg.sal_tot_batch)||
                              ' SAL_ACTUAL '||to_char(reg.sal_total)||
                              ' MOVIMIENTOS '||to_char(reg.m_monto)||
                              ' SAL_SEGUN_MOV '||to_char(reg.sal_tot_batch + reg.m_monto)||
                              ' DIFERENCIA '||to_char(reg.sal_total - ( reg.sal_tot_batch + reg.m_monto)));
  End loop;
end lp_cda_con_saldos;

-- Saldos con movimientos Vista................................................................18
procedure lp_ahv_saldos_vistas is
  Cursor Saldos is
  select nro_cuenta, sal_tot_batch, sal_total, m_monto
  from ah_cta_vistas x,
  (select nro_cuenta m_nro_cuenta,
        sum(decode(a.cod_transaccion, 515, 0, decode(tipo,'D',monto * -1, monto))) m_monto
   from ge_transacciones b,ge_movimientos a
  where nro_cuenta is not null
    and estado = 'N'
    and reversado = 'N'
    and monto <> 0
    and b.cod_modulo = a.cod_modulo
    and b.cod_modalidad = a.cod_modalidad
    and b.cod_transaccion = a.cod_transaccion
    and b.afecta <> 'N'
  group by nro_cuenta)
  where x.nro_cuenta = m_nro_cuenta
    and sal_tot_batch + m_monto <> sal_total;
begin
  For reg in Saldos loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              18,
                              'AV SALDO CON MOVIMIENTOS '||reg.nro_cuenta||
                              ' SAL BATCH '||to_char(reg.sal_tot_batch)||
                              ' SAL_ACTUAL '||to_char(reg.sal_total)||
                              ' MOVIMIENTOS '||to_char(reg.m_monto)||
                              ' SAL_SEGUN_MOV '||to_char(reg.sal_tot_batch + reg.m_monto)||
                              ' DIFERENCIA '||to_char(reg.sal_total - ( reg.sal_tot_batch + reg.m_monto)));
  End loop;
end lp_ahv_saldos_vistas;

-- Inconsistencia en ah_sal_mensuales..........................................................19
procedure lp_con_sal_mensuales is
  Cursor saldos is
  select nro_cuenta
    from ah_sal_mensuales a
   where exists (select 0 from ah_cta_vistas b
                  where b.nro_cuenta = a.nro_cuenta)
                    and not exists (select 0 from ah_cta_vistas b
                                     where a.nro_cuenta = b.nro_cuenta
                                       and a.cod_modulo = b.cod_modulo
                                       and a.cod_modalidad = b.cod_modalidad
                                       and a.cod_oficina = b.cod_oficina);
Begin
  For reg in saldos loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              19,
                              'Inconsistencia de datos entre AH_SAL_MENSUALES y AH_CTA_VISTAS');
  End loop;
end lp_con_sal_mensuales;

-- Inconsistencia en ge_tip_asientos...........................................................21
procedure lp_con_tip_asientos is
  Cursor Asientos is
   select nro_cuenta
     from ge_movimientos a
    where a.reversado = 'N'
      and a.cod_transaccion is not null
      and a.monto <> 0
      and a.cod_rubro is null
      and a.cod_transaccion not in (400,604)
      and not exists (select 0 from ge_tip_asientos b, ge_transacciones c
                       where b.cod_tip_asiento = c.cod_tip_asiento
                         and c.cod_transaccion = a.cod_transaccion
                         and c.cod_modulo = a.cod_modulo
                         and c.cod_modalidad = a.cod_modalidad
                         and b.cod_moneda = a.cod_moneda
                         and c.tipo in ('C','D')
                         and c.batch = 'B'
                         and c.afecta <> 'N');
begin
  For reg in Asientos loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              21,
                              'Inconsistencia de datos entre GE_MOVIMIENTOS y GE_TIP_ASIENTOS');
  End loop;
end lp_con_tip_asientos;

-- Cupones de cdas con Estado Incorrecto.......................................................22
procedure lp_cda_con_estado_incorrecto is
  Cursor cda is
    select a.nro_cuenta
    from ah_cta_certificados a, ah_cupones b
    where a.estado not in ('T','A','C','X')
    and b.nro_cuenta = a.nro_cuenta
    and b.estado not in ('E','V','P');


begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              22,
                              'Cupones de CDA con Estado Incorrecto');
  End loop;
end lp_cda_con_estado_incorrecto;

-- CDA con Estado Vencido y sin Saldo..........................................................23
procedure lp_cda_con_estado_vencido is
  Cursor cda is
    select a.nro_cuenta
    from ah_cta_certificados a
    where a.estado = 'V'
    and nvl(a.sal_total,0) = 0;

begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              23,
                              'CDA con Estado Vencido y sin Saldo');
  End loop;
end lp_cda_con_estado_vencido;

-- Personas con Direcciones por Defecto Duplicadas.............................................24
procedure lp_con_dir_duplicado is
  Cursor direcciones is
    select cod_persona
    from ba_direcciones x
    WHERE x.principal = 'S'
      and EXISTS (
    select a.cod_persona, a.principal, count(*)
    from ba_direcciones a
    where a.principal = 'S'
      and x.cod_persona = a.cod_persona
    GROUP BY a.cod_persona, a.principal
    having count(*) > 1);
begin
  For reg in direcciones loop
    insert into ge_controles (cod_persona,
                              cod_tip_control,
                              observacion)
                      values (reg.cod_persona,
                              24,
                              'Personas con Direcciones por Defecto Duplicadas');
  End loop;
end lp_con_dir_duplicado;

-- Clientes con Extractos con Error............................................................25
procedure lp_con_extracto is
  Cursor extractos is
    select cod_persona
    from ge_ext_clientes t
    where t.fre_extracto <> 'M';
begin
  For reg in extractos loop
    insert into ge_controles (cod_persona,
                              cod_tip_control,
                              observacion)
                      values (reg.cod_persona,
                              25,
                              'Clientes con Extractos con Error');
  End loop;
end lp_con_extracto;

--Certificados sin cupones.....................................................................26
procedure lp_cda_sin_cupones is
  Cursor cupones is
    select nro_cuenta
      from ah_cta_certificados a
     where not exists (select 0 from ah_cupones b
                       where b.nro_cuenta = a.nro_cuenta);
begin
  For reg in cupones loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              26,
                              'CDA sin cupones');
  End loop;
end lp_cda_sin_cupones;

--Cuentas con tasa personalizada relacionadas a tasas variables................................28
procedure lp_con_tas_personalizada is
  Cursor Vistas is
  select nro_cuenta
  from ah_cta_vistas
  where tas_personalizada = 'S'
  and cod_tasa in (34,35);
begin
  For reg in Vistas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              28,
                              'Tasa Personalizada de AV es Variable');
  End loop;
end lp_con_tas_personalizada;

--Cuentas con tasa personalizada cuyo codigo no coincide en ge_tas_fechas......................29
procedure lp_con_ge_tas_fechas is
  Cursor Vistas is
  select a.nro_cuenta
  from ah_cta_vistas a, ge_tas_fechas b
  where a.nro_cuenta = b.nro_cuenta
  and a.cod_tasa <> b.cod_tasa
  and a.cod_tasa in (34,35,36,37,38,39,40)
  and b.cod_tasa in (34,35,36,37,38,39,40);

begin
  For reg in Vistas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              29,
                              'AV : Codigo de tasa personalizada no coincide con GE_TAS_FECHAS');
  End loop;
end lp_con_ge_tas_fechas;

--Cuentas AV con firmas requeridas mayor a firmas registradas..................................30
procedure lp_ahv_con_firmas is
  Cursor Vistas is
  select a.nro_cuenta
  from ah_cta_vistas a
  where a.can_fir_requeridas > a.can_fir_registradas;

begin
  For reg in Vistas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              30,
                              'AV : firmas requeridas > firmas registradas');
  End loop;
end lp_ahv_con_firmas;

--Persona Juridica firmante de Cuentas que no esta como Principal..............................31
procedure lp_ahv_con_firmantes is
  Cursor Vistas is
  select a.nro_cuenta, a.cod_persona
  from ge_cta_clientes  a, ba_personas b
  where a.cod_persona = b.cod_persona
  and b.tipo = 'J'
  and a.relacion <> 'P';

begin
  For reg in Vistas loop
    insert into ge_controles (nro_cuenta,
                              cod_persona,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              reg.cod_persona,
                              31,
                              'Persona Juridica Firmante no esta como Principal');
  End loop;
end lp_ahv_con_firmantes;

--Cuentas CC con firmas requeridas mayor a firmas registradas..................................32
procedure lp_ctacte_con_firmas is
  Cursor CtaCte is
  select c.nro_cuenta
  from cc_cta_corrientes c
  where c.can_fir_requeridas > c.can_fir_registradas;

begin
  For reg in CtaCte loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              32,
                              'CC : firmas requeridas > firmas registradas');
  End loop;
end lp_ctacte_con_firmas;

--Cuentas inexistentes.........................................................................33
procedure lp_con_cta_inexistentes is
  Cursor Ctas is
  select c.nro_cuenta
    from ge_cta_clientes c
   where not exists (select 0 from ge_cuentas b
                      where b.nro_cuenta = c.nro_cuenta);

begin
  For reg in Ctas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              33,
                              'Cuenta inexistente en GE_CUENTAS.');
  End loop;

end lp_con_cta_inexistentes;

--Relaciones inexistentes......................................................................34
procedure lp_con_rel_inexistentes is
  Cursor Ctas is
  select c.nro_cuenta
    from ge_cuentas c
   where not exists (select 0 from ge_cta_clientes b
                      where b.nro_cuenta = c.nro_cuenta
                        and b.relacion = 'P');

begin
  For reg in Ctas loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              34,
                              'Cuenta inexistente en ge_cta_clientes.');
  End loop;
END;

--Firmante Principal Juridico no tiene firmante fisico.........................................38
procedure lp_con_dif_firmante4 is
    v_relacion ge_cta_clientes.relacion%type;
    Cursor Ctas is
    select g.cod_persona, g.nro_cuenta, g.relacion, p.tipo
    from ge_cta_clientes g, ba_personas p, ge_cuentas c
    where g.relacion = 'P'
    and g.cod_modulo in (3,4)
    and g.cod_persona = p.cod_persona
    and p.tipo = 'J'
		and g.nro_cuenta= c.nro_cuenta
		and c.estado not in ('C','T');

begin
    For reg in Ctas loop
        begin
          select 'S'
					into v_relacion
					from dual
					where reg.nro_cuenta in (
              					select g.nro_cuenta
                        from ge_cta_clientes g, ba_personas p
                        where g.relacion <> 'P'
                        and g.cod_modulo in (3,4)
                        and g.cod_persona = p.cod_persona
                        and p.tipo = 'F');
        exception
        when no_data_found then
            insert into ge_controles (nro_cuenta,
            cod_tip_control,cod_persona,
            observacion)
            values (reg.nro_cuenta,
            38,reg.cod_persona,
            'Firmante Principal Juridico no tiene firmante fisico');
						commit;
        end;
  End loop;
end lp_con_dif_firmante4;

--Cupones de CDA con valor cero................................................................39
procedure lp_cda_cupon_monto_cero is
    Cursor Ctas is
    select a.nro_cuenta
		from ah_cupones a
		where a.mto_interes = 0 or a.mto_interes is null
;

begin
    For reg in Ctas loop
        insert into ge_controles (nro_cuenta, cod_tip_control, observacion)
        values (reg.nro_cuenta, 39, 'Cupones de CDA con valor cero');
    		commit;
    End loop;
end lp_cda_cupon_monto_cero;

-- Cupones CDA pagados sin fecha de pago.......................................................41
procedure lp_cda_cupon_pagado_sin_fecha is
  Cursor cupon is
    select nro_cuenta
    from ah_cupones
    where estado = 'P'
    and fec_pago is null;
begin
  For reg in cupon loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              41,
                              'Cupones CDA pagados sin fecha de pago');
  End loop;
end lp_cda_cupon_pagado_sin_fecha;

-- Saldo total de CDA menor al capital.........................................................42
procedure lp_cda_saldo_menor_capital is
  Cursor cda is
    select nro_cuenta
    from ah_cta_certificados
    where nvl(sal_total,0) < capital
    and estado in ('V','N') and est_certificado <> 'P';
begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              42,
                              'Saldo total de CDA menor al capital');
  End loop;
end lp_cda_saldo_menor_capital;

--Serie de CDA no identificada.................................................................43
procedure lp_cda_serie_desconocida is
  Cursor cda is
    select nro_cuenta
    from ah_cta_certificados
    where serie not between 'A' and 'ZZ'
    and estado in ('V','N');
begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              43,
                              'Serie de CDA no identificada');
  End loop;
end lp_cda_serie_desconocida;

--Cuentas CDA sin cupones vencidos en el saldo.................................................44
procedure lp_cda_saldo_sin_interes is
  Cursor cda is
    select a.nro_cuenta
    from ah_cta_certificados a,
          (select nro_cuenta cuenta, sum(mto_interes) cup_vencidos
          from ah_cupones
          where estado = 'V'
          group by nro_cuenta) b
    where a.estado in ('N','V')
      and b.cuenta(+) = a.nro_cuenta
      and a.sal_total - decode(a.est_certificado,'P',0,nvl(a.capital,0)) <> nvl(b.cup_vencidos,0);
begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              44,
                              'Cuentas CDA sin cupones vencidos en el saldo');
  End loop;
end lp_cda_saldo_sin_interes;

--Numero de CDA no valido......................................................................45
procedure lp_cda_nro_invalido is
  Cursor cda is
    select nro_cuenta
		from ah_cta_certificados
    where nvl(nro_certificado,0) not between 1 and 9999
    and estado in ('V','N');
begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              45,
                              'Numero de CDA no valido');
  End loop;
end lp_cda_nro_invalido;


--Fecha de apertura CDA mayor al vencimiento...................................................46
procedure lp_cda_fecha_apertura is
  Cursor cda is
    select nro_cuenta
    from ah_cta_certificados
    where fec_apertura > fec_vencimiento
    and estado in ('V','N');
begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              46,
                              'Fecha de apertura CDA mayor al vencimiento');
  End loop;
end lp_cda_fecha_apertura;

--Cuentas CDA sin beneficiario.................................................................47
procedure lp_cda_sin_beneficiario is
  Cursor cda is
    select nro_cuenta
		from ah_cta_certificados
    where beneficiario is null
    and estado in ('V','N');
begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              47,
                              'Cuentas CDA sin beneficiario');
  End loop;
end lp_cda_sin_beneficiario;


--Vencimiento CDA menor a vcto ultimo cupon....................................................48
procedure lp_cda_ult_vcto_cupon is
  Cursor cda is
  select a.nro_cuenta nro_cuenta
  from ah_cta_certificados a,
       ( select nro_cuenta, max(nro_cupon) nro_cupon
        from ah_cupones
        group by nro_cuenta ) b,
  			ah_cupones c
  where a.nro_cuenta = b.nro_cuenta
  and b.nro_cuenta = c.nro_cuenta
  and b.nro_cupon = c.nro_cupon
  and a.fec_vencimiento <> c.fec_vencimiento;
begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              48,
                              'Vencimiento CDA menor a vcto ultimo cupon');
  End loop;
end lp_cda_ult_vcto_cupon;

-- Cuentas de cdas con Estado Incorrecto.......................................................49
procedure lp_cda_con_estado_incorrecto2 is
  Cursor cda is
  select nro_cuenta
  from ah_cta_certificados
  where estado in ('A','X','T')
  and ah_cta_certificados.sal_total > 0;


begin
  For reg in cda loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              49,
                              'Cuentas de CDA con Estado Incorrecto');
  End loop;
end lp_cda_con_estado_incorrecto2;

-- Prestamos estado='N' con cuotas pagadas.....................................................50
procedure lp_ptmo_con_estado_incorrecto is
  Cursor ptmo is
    select t.nro_cuenta, t.estado, t.est_batch
    from pr_cta_prestamos t
    where t.estado != 'N'
    and not exists (select 1 from pr_cuotas a
    where a.nro_cuenta = t.nro_cuenta
    and a.estado <> 'N');

begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              50,
                              'Prestamos estado = "N" con cuotas pagadas');
  End loop;
end lp_ptmo_con_estado_incorrecto;

-- Prestamos con fecha de Inicio > al Vencimiento..............................................51
procedure lp_ptmo_Inicio is
  Cursor ptmo is
    select t.nro_cuenta, t.cod_modalidad, t.sal_capital, t.sal_interes, t.fec_inicio, t.fec_vencimiento
    from pr_cta_prestamos t
    where t.estado <> 'N'
    and t.fec_inicio > t.fec_vencimiento;


begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              51,
                              'Prestamos Inicio > Vencimiento');
  End loop;
end lp_ptmo_Inicio;


-- Prestamos Devengado y Cuotas................................................................52
procedure lp_ptmo_devengado_cuotas is
  Cursor ptmo is
        select 'INT PRESTAMO <> INT CUOTA' obs, t.nro_cuenta, t.cod_moneda, t.estado,
               nvl(T.DEV_ACUMULADO,0) DEV_ACUMULADO,
               nvl(T.VAL_INT_DEVENGAR,0) val_int_devengar,
               nvl(T.DEV_ACUMULADO,0)+nvl(T.VAL_INT_DEVENGAR,0) mto_int_prestamo,
               nvl(cup_MTO_INTERES,0) mto_int_cuota,
               (nvl(T.DEV_ACUMULADO,0)+nvl(T.VAL_INT_DEVENGAR,0)) - nvl(cup_MTO_INTERES,0) dif
        from pr_cta_prestamos t,
        (
        SELECT A.NRO_CUENTA cup_NRO_CUENTA,
               SUM(NVL(A.MTO_INTERES,0)+nvl(A.MTO_INT_DOCUMENTADO,0)) cup_MTO_INTERES,
               SUM(NVL(A.SAL_INTERES,0)+NVL(A.SAL_INT_DOCUMENTADO,0)) cup_SAL_INTERES,
               SUM(NVL(A.SAL_CAPITAL,0)) cup_SAL_CAPITAL,
               SUM(decode(a.estado,'N',NVL(A.MTO_INTERES,0)+NVL(A.MTO_INT_DOCUMENTADO,0),0)) cup_MTO_PAGADO,
               sum(nvl(a.dev_no_cobrado,0)) cup_dev_no_cobrado,
               sum(nvl(a.dev_suspenso,0)) cup_dev_suspenso,
               sum(nvl(a.dev_acumulado,0)) cup_dev_acumulado
          FROM pr_cuotas A
         WHERE A.NRO_CUOTA > 0
        GROUP BY A.NRO_CUENTA
        )
        WHERE t.estado <> 'N'
          and cup_NRO_CUENTA(+) = T.NRO_CUENTA
          and (nvl(T.DEV_ACUMULADO,0)+nvl(T.VAL_INT_DEVENGAR,0)) <>
               nvl(cup_MTO_INTERES,0)
        union all
        select 'INT ACUM_PRESTAMO <> INT ACUM_CUOTA' obs, t.nro_cuenta, t.cod_moneda, t.estado,
               0,0,
               nvl(T.DEV_ACUMULADO,0) dev_acum_pres,
               nvl(cup_dev_acumulado,0) dev_acum_cuota,
               nvl(T.DEV_ACUMULADO,0) - nvl(cup_dev_acumulado,0) dif
        from pr_cta_prestamos t,
        (
        SELECT A.NRO_CUENTA cup_NRO_CUENTA,
               SUM(NVL(A.MTO_INTERES,0)) cup_MTO_INTERES,
               SUM(NVL(A.SAL_INTERES,0)) cup_SAL_INTERES,
               SUM(NVL(A.SAL_CAPITAL,0)) cup_SAL_CAPITAL,
               SUM(decode(a.estado,'N',NVL(A.MTO_INTERES,0),0)) cup_MTO_PAGADO,
               sum(nvl(a.dev_no_cobrado,0)) cup_dev_no_cobrado,
               sum(nvl(a.dev_suspenso,0)) cup_dev_suspenso,
               sum(nvl(a.dev_acumulado,0)) cup_dev_acumulado
          FROM pr_cuotas A
         WHERE A.NRO_CUOTA > 0
        GROUP BY A.NRO_CUENTA
        )
        WHERE t.estado <> 'N'
          and cup_NRO_CUENTA(+) = T.NRO_CUENTA
          and nvl(T.DEV_ACUMULADO,0) <> nvl(cup_dev_acumulado,0)
        union all
        select 'INT NOCOB_PRESTAMO <> INT NOCOB_CUOTA' obs, t.nro_cuenta, t.cod_moneda, t.estado,
               0,0,
               nvl(T.DEV_NO_COBRADO,0) dev_nocob_pres,
               nvl(cup_dev_no_cobrado,0) dev_nocob_cuota,
               nvl(T.DEV_NO_COBRADO,0) - nvl(cup_dev_no_cobrado,0) dif
        from pr_cta_prestamos t,
        (
        SELECT A.NRO_CUENTA cup_NRO_CUENTA,
               SUM(NVL(A.MTO_INTERES,0)) cup_MTO_INTERES,
               SUM(NVL(A.SAL_INTERES,0)) cup_SAL_INTERES,
               SUM(NVL(A.SAL_CAPITAL,0)) cup_SAL_CAPITAL,
               SUM(decode(a.estado,'N',NVL(A.MTO_INTERES,0),0)) cup_MTO_PAGADO,
               sum(nvl(a.dev_no_cobrado,0)) cup_dev_no_cobrado,
               sum(nvl(a.dev_suspenso,0)) cup_dev_suspenso,
               sum(nvl(a.dev_acumulado,0)) cup_dev_acumulado
          FROM pr_cuotas A
         WHERE A.NRO_CUOTA > 0
        GROUP BY A.NRO_CUENTA
        )
        WHERE t.estado <> 'N'
          and cup_NRO_CUENTA(+) = T.NRO_CUENTA
          and nvl(T.DEV_NO_COBRADO,0) <> nvl(cup_dev_no_cobrado,0)
        union all
        select 'INT SUSP_PRESTAMO <> INT SUSP_CUOTA' obs, t.nro_cuenta, t.cod_moneda, t.estado,
               0,0,
               nvl(T.DEV_suspenso,0) dev_susp_pres,
               nvl(cup_dev_no_cobrado,0) dev_susp_cuota,
               nvl(T.DEV_suspenso,0) - nvl(cup_dev_suspenso,0) dif
        from pr_cta_prestamos t,
        (
        SELECT A.NRO_CUENTA cup_NRO_CUENTA,
               SUM(NVL(A.MTO_INTERES,0)) cup_MTO_INTERES,
               SUM(NVL(A.SAL_INTERES,0)) cup_SAL_INTERES,
               SUM(NVL(A.SAL_CAPITAL,0)) cup_SAL_CAPITAL,
               SUM(decode(a.estado,'N',NVL(A.MTO_INTERES,0),0)) cup_MTO_PAGADO,
               sum(nvl(a.dev_no_cobrado,0)) cup_dev_no_cobrado,
               sum(nvl(a.dev_suspenso,0)) cup_dev_suspenso,
               sum(nvl(a.dev_acumulado,0)) cup_dev_acumulado
          FROM pr_cuotas A
         WHERE A.NRO_CUOTA > 0
        GROUP BY A.NRO_CUENTA
        )
        WHERE t.estado <> 'N'
          and cup_NRO_CUENTA(+) = T.NRO_CUENTA
          and nvl(T.DEV_suspenso,0) <> nvl(cup_dev_suspenso,0);


begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              52,
                              'Prestamos Devengado y Cuotas');
  End loop;
end lp_ptmo_devengado_cuotas;


-- Prestamos Cartera...........................................................................53
procedure lp_ptmo_cartera is
  Cursor ptmo is
      SELECT PR.COD_MONEDA MON, NRO_CUENTA,
             FEC_ULT_DEVENGADO ULT_DEV, TIP_INTERES TIP_INT,
             (NVL(PR.VAL_INT_DEVENGAR,0)) INT_DEVENGAR,
             (CUP_MTO_INTERES - NVL(PR.DEV_ACUMULADO,0)) CUOTA,
             (NVL(PR.VAL_INT_DEVENGAR,0)) -
             (CUP_MTO_INTERES - NVL(PR.DEV_ACUMULADO,0)) DIF,
             (NVL(PR.DEV_ACUMULADO,0)) DEV_ACUMULADO,
             (NVL(CUP_DEV_ACUMULADO,0)) CUOTA1,
             (NVL(PR.DEV_ACUMULADO,0)) - (NVL(CUP_DEV_ACUMULADO,0)) DIF1,
             (NVL(PR.DEV_NO_COBRADO,0)) DEV_NO_COBRADO,
             (NVL(CUP_DEV_NO_COBRADO,0)) CUOTA2,
             (NVL(PR.DEV_NO_COBRADO,0)) - (NVL(CUP_DEV_NO_COBRADO,0)) DIF2,
             (NVL(PR.DEV_SUSPENSO,0)) DEV_SUSPENSO,
             (NVL(CUP_DEV_SUSPENSO,0)) CUOTA3,
             (NVL(PR.DEV_SUSPENSO,0)) - (NVL(CUP_DEV_SUSPENSO,0)) DIF3,
             (NVL(PR.SAL_INTERES,0)+NVL(PR.SAL_INT_ADELANTADO,0)) SAL_INTERES,
             (NVL(CUP_SAL_INTERES,0)) CUOTA4,
             (NVL(PR.SAL_INTERES,0)+NVL(PR.SAL_INT_ADELANTADO,0)) - (NVL(CUP_SAL_INTERES,0)) DIF4,
             (NVL(PR.SAL_INTERES,0)) SAL_INTERES1,
             (NVL(PR.VAL_INT_DEVENGAR,0)+NVL(PR.DEV_NO_COBRADO,0)+NVL(PR.DEV_SUSPENSO,0)) DEVENGADO,
             (NVL(PR.SAL_INTERES,0)) -
             (NVL(PR.VAL_INT_DEVENGAR,0)+NVL(PR.DEV_NO_COBRADO,0)+NVL(PR.DEV_SUSPENSO,0)) DIF5,
             (NVL(PR.SAL_CAPITAL,0)) SAL_CAPITAL,
             (NVL(CUP_SAL_CAPITAL,0)) CUOTA5,
             (NVL(PR.SAL_CAPITAL,0)) - (NVL(CUP_SAL_CAPITAL,0)) DIF6
      FROM (SELECT A.NRO_CUENTA CUP_NRO_CUENTA,
                   SUM(NVL(B.DEV_ACUMULADO,0)) CUP_DEV_ACUMULADO,
                   SUM(NVL(B.DEV_NO_COBRADO,0)) CUP_DEV_NO_COBRADO,
                   SUM(NVL(B.DEV_SUSPENSO,0)) CUP_DEV_SUSPENSO,
                   SUM(NVL(B.SAL_INTERES,0)+NVL(B.SAL_INT_DOCUMENTADO,0)) CUP_SAL_INTERES,
                   SUM(NVL(B.MTO_INTERES,0)+NVL(B.MTO_INT_DOCUMENTADO,0)) CUP_MTO_INTERES,
                   SUM(NVL(B.SAL_CAPITAL,0)) CUP_SAL_CAPITAL
              FROM PR_CTA_PRESTAMOS A, PR_CUOTAS B
             WHERE A.ESTADO not in ('N','I')
               AND B.NRO_CUENTA = A.NRO_CUENTA
               and b.nro_cuota > 0
             GROUP BY A.NRO_CUENTA),
            PR_CTA_PRESTAMOS PR
      WHERE PR.ESTADO not in ('N','I')
        AND PR.NRO_CUENTA = CUP_NRO_CUENTA
      and (
             ((NVL(PR.DEV_ACUMULADO,0)) - (NVL(CUP_DEV_ACUMULADO,0))) != 0 OR
             ((NVL(PR.DEV_NO_COBRADO,0)) - (NVL(CUP_DEV_NO_COBRADO,0))) != 0 OR
             ((NVL(PR.DEV_SUSPENSO,0)) - (NVL(CUP_DEV_SUSPENSO,0))) != 0 OR
             ((NVL(PR.SAL_INTERES,0)+NVL(PR.SAL_INT_ADELANTADO,0)) - (NVL(CUP_SAL_INTERES,0))) != 0 OR
             ((NVL(PR.SAL_CAPITAL,0)) - (NVL(CUP_SAL_CAPITAL,0))) != 0 OR
             ((NVL(PR.VAL_INT_DEVENGAR,0)) - (CUP_MTO_INTERES - NVL(PR.DEV_ACUMULADO,0)))  != 0
          );
begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              53,
                              'Prestamos Cartera');
  End loop;
end lp_ptmo_cartera;


-- Prestamo Adelantado sin Saldo Adelantado....................................................54
procedure lp_ptmo_adelantado is
  Cursor ptmo is
      select t.nro_cuenta
      from pr_cta_prestamos t
      WHERE T.ESTADO <> 'N'
      AND NVL(T.TIP_INTERES,'X') = 'A'
      AND T.SAL_INT_ADELANTADO = 0
      and t.sal_interes > 0;

begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              54,
                              'Prestamo Adelantado sin Saldo Adelantado');
  End loop;
end lp_ptmo_adelantado;

-- Prestamo no Adelantado con Saldo Adelantado.................................................55
procedure lp_ptmo_no_adelantado is
  Cursor ptmo is
    select t.nro_cuenta
    from pr_cta_prestamos t
    WHERE T.ESTADO <> 'N'
    AND NVL(T.TIP_INTERES,'X') != 'A'
    AND T.SAL_INT_ADELANTADO > 0;
begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              55,
                              'Prestamo no Adelantado con Saldo Adelantado');
  End loop;
end lp_ptmo_no_adelantado;

-- Prestamo a devengar y cuotas................................................................56
procedure lp_ptmo_adevengar_cuotas is
  Cursor ptmo is
    select a.nro_cuenta, a.fec_ult_devengado, a.val_int_devengar a_dev_cabecera,
           cu_val_int_devengar a_dev_detalle,
           a.val_int_devengar - cu_val_int_devengar dif_a_dev
    from pr_cta_prestamos a,
    (select b.nro_cuenta cu_nro_cuenta,
            sum(nvl(b.mto_interes,0)+ nvl(b.mto_int_documentado,0)) cu_mto_interes,
            sum(nvl(b.dev_acumulado,0)) cu_dev_acumulado,
            sum(nvl(b.mto_interes,0)+ nvl(b.mto_int_documentado,0)) - sum(nvl(b.dev_acumulado,0)) cu_val_int_devengar
    from pr_cuotas b
    where b.nro_cuota > 0
      and b.estado <> 'N'
    group by b.nro_cuenta
    )
    where a.estado <> 'N'
      and a.val_int_devengar > 0
      and nvl(a.val_int_devengar,0) != nvl(cu_val_int_devengar,0)
      and cu_nro_cuenta = a.nro_cuenta;

begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              56,
                              'Prestamo a devengar y cuotas');
  End loop;
end lp_ptmo_adevengar_cuotas;


-- Prestamo Cuota pago anticipado..............................................................57
procedure lp_ptmo_cuo_pago_anticipado is
  Cursor ptmo is
    select t.nro_cuenta
    from pr_cuotas t
    where t.estado <> 'N'
      and t.nro_cuota > 0
      and exists (select 1 from pr_cta_prestamos x
                        where x.nro_cuenta = t.nro_cuenta
                          and x.estado <> 'N')
      and t.nro_cuota < (select max(y.nro_cuota)
                           from pr_cuotas y
                          where y.nro_cuenta = t.nro_cuenta
                            and y.estado = 'N'
                            );
begin
  For reg in ptmo loop
    insert into ge_controles (nro_cuenta,
                              cod_tip_control,
                              observacion)
                      values (reg.nro_cuenta,
                              57,
                              'Prestamo Cuota pago anticipado');
  End loop;
end lp_ptmo_cuo_pago_anticipado;

-- Cabecera de Garantia no coincide con el Detalle.............................................58
procedure lp_dif_garantia_detalle is
  Cursor garantia is
      select 'GARANTIA HIPOTECARIA NRO. '||to_char(nro_garantia)||' NO COINCIDE CON EL DETALLE' detalle
      from pr_garantias
      where cod_garantia IN (3, 13)  -- Res. 12
      and val_tasacion <> (select sum(val_edilicio+val_terreno)
                           from pr_gar_hipotecarias
                           where nro_garantia = pr_garantias.nro_garantia)
      union all
      select 'GARANTIA PRENDARIA NRO. '||to_char(nro_garantia)||' NO COINCIDE CON EL DETALLE' detalle
      from pr_garantias
      where cod_garantia = 4
      and val_tasacion <> (select sum(nvl(val_tasacion,0))
                           from pr_gar_vehiculos
                           where nro_garantia = pr_garantias.nro_garantia)
      union all
      select 'GARANTIA CASH COLLATERAL NRO. '||to_char(nro_garantia)||' NO COINCIDE CON EL DETALLE' detalle
      from pr_garantias
      where cod_garantia = 5
      and valor <> (select sum(nvl(monto,0))
                           from pr_gar_cash
                           where nro_garantia = pr_garantias.nro_garantia)
      union all
      select 'GARANTIA WARRANT NRO. '||to_char(nro_garantia)||' NO COINCIDE CON EL DETALLE' detalle
      from pr_garantias
      where cod_garantia = 6
      and valor <> (select sum(nvl(val_unitario,1)*nvl(cantidad,1))
                           from pr_gar_warrants
                           where nro_garantia = pr_garantias.nro_garantia)
      union all
      select 'GARANTIA CAUCION NRO. '||to_char(nro_garantia)||' NO COINCIDE CON EL DETALLE' detalle
      from pr_garantias
      where cod_garantia = 7
      and valor <> (select sum(nvl(monto,0))
                           from pr_gar_documentos
                           where nro_garantia = pr_garantias.nro_garantia);
begin
  For reg in garantia loop
    insert into ge_controles (cod_tip_control,
                              observacion)
                      values (58,
                              reg.detalle);
  End loop;
end lp_dif_garantia_detalle;


-- Valor de Venta Rapida mayor al Valor de Garantia............................................59
procedure lp_gar_val_vta_rapida is
   Cursor garantia is
      select 'VAL_VTA_RAPIDA DE GARANTIA HIPOTECARIA NRO. '||to_char(nro_garantia)||' MAYOR AL VALOR DE LA GARANTIA' detalle
      from pr_gar_hipotecarias
      where (nvl(val_edilicio,0) + nvl(val_terreno,0)) < val_vta_rapida
      union all
      select 'VAL_VTA_RAPIDA DE GARANTIA PRENDARIA NRO. '||to_char(nro_garantia)||' MAYOR AL VALOR DE LA GARANTIA' detalle
      from pr_gar_vehiculos
      where (nvl(val_tasacion,0)) < nvl(val_vta_rapida,0);
begin
  For reg in garantia loop
    insert into ge_controles (cod_tip_control,
                              observacion)
                      values (59,
                              reg.detalle);
  End loop;
end lp_gar_val_vta_rapida;


-- Cantidad de ONP en chequeras no coincide con CC_CHE_ORD_NO_PAGOS............................60
procedure lp_che_ord_no_pagos is
  v_cantidad1 number;--cantidad de cheques ONP en cc_che_ord_no_pagos
  v_cantidad2 number;--cantidad de cheques ONP en cc_chequeras
begin
  --Cantidad de ONP en CC_CHE_ORD_NO_PAGOS
  select nvl(count(*),0)
  into v_cantidad1
  from cc_che_ord_no_pagos;

  --Cantidad de ONP en CC_CHEQUERAS
  select nvl(sum(ch.can_cheques - nvl(length(replace(ch.est_cheques, 'O', '')), 0)),0)
  into   v_cantidad2
  from cc_chequeras ch
  where ch.can_cheques - nvl(length(replace(ch.est_cheques, 'O', '')), 0) <> 0;
  
  --Si las cantidades son distintas inserto en ge_controles
  if v_cantidad1 <> v_cantidad2 then
    insert into ge_controles (cod_tip_control, observacion)
    values (60, 'Cantidad de ONP en CC_CHEQUERAS '||v_cantidad1||'no coincide con CC_CHE_ORD_NO_PAGOS '||v_cantidad2);
  end if;  

end lp_che_ord_no_pagos;

-- Diferencias de ONP por cuentas..............................................................61
procedure lp_che_ord_no_pagos1 is
  Cursor onp is
  select nro_cuenta, serie, nro_che_inicial, nro_che_final, est_cheques, 
  (can_cheques - nvl(length(REPLACE(est_cheques, 'O', '')), 0)) can_onp
  from cc_chequeras
  where est_cheques like '%O%';

  v_cantidad1 number;--cantidad de cheques ONP en cc_che_ord_no_pagos
  v_cantidad2 number;--cantidad de cheques ONP en cc_chequeras
begin
  --Recorrer todas las chequeras para contar los ONP
  FOR reg IN onp LOOP
    BEGIN
      v_cantidad2 := reg.can_onp;

      select nvl(count(*),0)
      into v_cantidad1
      from cc_che_ord_no_pagos
      where nro_cuenta = reg.nro_cuenta
      and nro_cheque between reg.nro_che_inicial and reg.nro_che_final;

      --Si las cantidades son distintas inserto en ge_controles
      IF v_cantidad1 <> v_cantidad2 THEN
        insert into ge_controles (cod_tip_control, nro_cuenta, observacion)
        values (61, reg.nro_cuenta, 'Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Cantidad ONP CC_CHEQUERAS '||v_cantidad1||' Cantidad en CC_CHE_ORD_NO_PAGOS '||v_cantidad2);
      END IF;

   	END;
	END LOOP;
end lp_che_ord_no_pagos1;

-- Cantidad de certificados en chequeras no coincide con CC_CHE_CERTIFICADOS.................62
procedure lp_che_cert is
  v_cantidad1 number;--cantidad de cheques certificados en cc_che_certificados
  v_cantidad2 number;--cantidad de cheques certificados en cc_chequeras
begin
  select nvl(count(*),0)
  into v_cantidad1
  from cc_che_certificados;

  --Cantidad de ONP en CC_CHEQUERAS
  select nvl(sum(ch.can_cheques - nvl(length(replace(ch.est_cheques, 'C', '')), 0)),0)
  into   v_cantidad2
  from cc_chequeras ch
  where ch.can_cheques - nvl(length(replace(ch.est_cheques, 'C', '')), 0) <> 0;

  --Si las cantidades son distintas inserto en ge_controles
  if v_cantidad1 <> v_cantidad2 then
    insert into ge_controles (cod_tip_control, observacion)
    values (62, 'Cantidad certificados CC_CHEQUERAS '||v_cantidad1||' no coincide con CC_CHE_CERTIFICADOS '||v_cantidad2);
  end if;

end lp_che_cert;

-- Diferencias de CERTIFICADOS por cuentas....................................................63
procedure lp_che_cert1 is
  Cursor cert is
  select nro_cuenta, serie, nro_che_inicial, nro_che_final, est_cheques, 
  (can_cheques - nvl(length(replace(est_cheques, 'C', '')), 0)) can_cert
  from cc_chequeras
  where est_cheques like '%C%';

  v_cantidad1 number;--cantidad de cheques CERTIFICADOS en cc_che_certificados
  v_cantidad2 number;--cantidad de cheques CERTIFICADOS en cc_chequeras
begin
  --Recorrer todas las chequeras para contar los ONP
  FOR reg IN cert LOOP
    BEGIN
      v_cantidad2 := reg.can_cert;

      select nvl(count(*),0)
      into v_cantidad1
      from cc_che_certificados
      where nro_cuenta = reg.nro_cuenta
      and nro_cheque between reg.nro_che_inicial and reg.nro_che_final;

      --Si las cantidades son distintas inserto en ge_controles
      IF v_cantidad1 <> v_cantidad2 THEN
        insert into ge_controles (cod_tip_control, nro_cuenta, observacion)
        values (63, reg.nro_cuenta, 'Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Cantidad CERTIFICADO CC_CHEQUERAS '||v_cantidad1||' Cantidad en CC_CHE_CERTIFICADOS '||v_cantidad2);
      END IF;

   	END;
	END LOOP;
end lp_che_cert1;

-- Cantidad de anulados en chequeras no coincide con CC_CHE_ANULADOS..........................64
procedure lp_che_anulados is
  v_cantidad1 number;--cantidad de cheques anulados en cc_che_anulados
  v_cantidad2 number;--cantidad de cheques anulados en cc_chequeras
begin
  select nvl(count(*),0)
  into v_cantidad1
  from cc_che_anulados;

  --Cantidad de ANUALDOS en CC_CHEQUERAS
  select nvl(sum(ch.can_cheques - nvl(length(replace(ch.est_cheques, 'A', '')), 0)),0)
  into   v_cantidad2
  from cc_chequeras ch
  where ch.can_cheques - nvl(length(replace(ch.est_cheques, 'A', '')), 0) <> 0;

  --Si las cantidades son distintas inserto en ge_controles
  IF v_cantidad1 <> v_cantidad2 THEN
    insert into ge_controles (cod_tip_control, observacion)
    values (64, 'Cantidad de anulados en CC_CHEQUERAS '||v_cantidad1||' no coincide con CC_CHE_ANULADOS '||v_cantidad2);
  END IF;  
end lp_che_anulados;


-- Diferencias de ANULADOS por cuentas........................................................65
procedure lp_che_anulados1 is
  Cursor anul is
  select nro_cuenta, serie, nro_che_inicial, nro_che_final, est_cheques, 
  (can_cheques - nvl(length(replace(est_cheques, 'A', '')), 0)) can_anul
  from cc_chequeras
  where est_cheques like '%A%';

  v_cantidad1 number;--cantidad de cheques ANULADOS en cc_che_anualdos
  v_cantidad2 number;--cantidad de cheques ANULADOS en cc_chequeras
begin
  --Recorrer todas las chequeras para contar los ONP
  FOR reg IN anul LOOP
    BEGIN
      v_cantidad1 := reg.can_anul;

      select nvl(count(*),0)
      into v_cantidad2
      from cc_che_anulados
      where nro_cuenta = reg.nro_cuenta
      and nro_cheque between reg.nro_che_inicial and reg.nro_che_final;

      --Si las cantidades son distintas inserto en ge_controles
      IF v_cantidad1 <> v_cantidad2 THEN
        insert into ge_controles (cod_tip_control, nro_cuenta, observacion)
        values (65, reg.nro_cuenta, 'Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Cantidad ANULADOS CC_CHEQUERAS '||v_cantidad1||' Cantidad en CC_CHE_ANULADOS '||v_cantidad2);
      END IF;
   	END;
	END LOOP;
end lp_che_anulados1;

-- Cantidad de pagados en chequeras no coincide con CC_CHE_PAGADOS..........................66
procedure lp_che_pagados is
  v_cantidad1 number;--cantidad de cheques PAGADOS en cc_che_pagados
  v_cantidad2 number;--cantidad de cheques PAGADOS en cc_chequeras
begin
  select nvl(count(*),0)
  into v_cantidad1
  from cc_che_pagados;

  --Cantidad de ANUALDOS en CC_CHEQUERAS
  select nvl(sum(ch.can_cheques - nvl(length(replace(ch.est_cheques, 'P', '')), 0)),0)
  into   v_cantidad2
  from cc_chequeras ch
  where ch.can_cheques - nvl(length(replace(ch.est_cheques, 'P', '')), 0) <> 0;

  --Si las cantidades son distintas inserto en ge_controles
  IF v_cantidad1 <> v_cantidad2 THEN
    insert into ge_controles (cod_tip_control, observacion)
    values (66, 'Cantidad de pagados en CC_CHEQUERAS '||v_cantidad1||' no coincide con CC_CHE_PAGADOS '||v_cantidad2);
  END IF;  
end lp_che_pagados;

-- Diferencias de PAGADOS por cuentas.........................................................67
procedure lp_che_pagados1 is
  Cursor anul is
  select nro_cuenta, serie, nro_che_inicial, nro_che_final, est_cheques, 
  (can_cheques - nvl(length(replace(est_cheques, 'P', '')), 0)) can_anul
  from cc_chequeras
  where est_cheques like '%P%';

  v_cantidad1 number;--cantidad de cheques ANULADOS en cc_che_anualdos
  v_cantidad2 number;--cantidad de cheques ANULADOS en cc_chequeras
begin
  --Recorrer todas las chequeras para contar los ONP
  FOR reg IN anul LOOP
    BEGIN
      v_cantidad1 := reg.can_anul;

      select nvl(count(*),0)
      into v_cantidad2
      from cc_che_pagados
      where nro_cuenta = reg.nro_cuenta
      and nro_cheque between reg.nro_che_inicial and reg.nro_che_final;

      --Si las cantidades son distintas inserto en ge_controles
      IF v_cantidad1 <> v_cantidad2 THEN
        insert into ge_controles (cod_tip_control, nro_cuenta, observacion)
        values (67, reg.nro_cuenta, 'Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Cantidad PAGADOS CC_CHEQUERAS '||v_cantidad1||' Cantidad en CC_CHE_PAGADOS '||v_cantidad2);
      END IF;
   	END;
	END LOOP;
end lp_che_pagados1;

-- Diferencias de CHEQUERAS por cuentas.......................................................68
procedure lp_chequera is
  Cursor chequera is
  select nro_cuenta, serie, nro_che_inicial, nro_che_final
  from cc_chequeras
  where ((nro_che_final-nro_che_inicial)+1) <> can_cheques;

begin
  --Recorrer todas las chequeras cuyo nro_final-nro_final <> can_cheques
  FOR reg IN chequera LOOP
    BEGIN
        insert into ge_controles (cod_tip_control, nro_cuenta, observacion)
        values (68, reg.nro_cuenta, 'Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Nro. Che. Final: '||reg.nro_che_final);
   	END;
	END LOOP;
end lp_chequera;

-- Diferencias de CHEQUERAS por cuentas.......................................................69
procedure lp_chequera1 is
  Cursor chequera is
  select nro_cuenta, serie, nro_che_inicial, nro_che_final
  from cc_chequeras
  where can_cheques <> length(est_cheques);

begin
  --Recorrer todas las chequeras cuyo can_cheques <> length(est_cheques)
  FOR reg IN chequera LOOP
    BEGIN
        insert into ge_controles (cod_tip_control, nro_cuenta, observacion)
        values (69, reg.nro_cuenta, 'Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Nro. Che. Final: '||reg.nro_che_final);
   	END;
	END LOOP;
end lp_chequera1;

-- Diferencias de CC_CHE_VENTANILLAS..........................................................70
procedure lp_che_ventanilla is
  Cursor cheven is
  select serie, cod_moneda, nro_che_inicial, nro_che_final, ult_che_emitido
  from cc_che_ventanillas 
  where nvl(ult_che_emitido,0) <> 0
  and (ult_che_emitido-nro_che_inicial)+1 <> (select nvl(count(*),0)
                                            from cc_chequeras
                                            where serie = cc_che_ventanillas.serie
                                            and nro_che_inicial between cc_che_ventanillas.nro_che_inicial and ult_che_emitido);
begin
  --Recorrer cheques ventanilla emitidos vs registrados en CC_CHEQUERAS
  FOR reg IN cheven LOOP
    BEGIN
        insert into ge_controles (cod_tip_control, observacion)
        values (70, ' Moneda: '||reg.cod_moneda||' Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Ult. Che. Emitido: '||reg.ult_che_emitido);
   	END;
	END LOOP;
end lp_che_ventanilla;

-- Diferencias de CC_CHE_GER_EMITIDOS.........................................................71
procedure lp_che_gerencia is
  Cursor cheger is
  select nro_cuenta, serie, nro_che_inicial, nro_che_final, ult_che_emitido
  from cc_chequeras 
  where exists (select 1 
                from cc_cta_bancarias 
                where cod_modalidad = 43
                and nro_cuenta = cc_chequeras.nro_cuenta)
  and nvl(ult_che_emitido,0) <> 0
  and (ult_che_emitido-nro_che_inicial)+1 <> (select nvl(count(*),0)
                                              from cc_che_ger_emitidos
                                              where nro_cuenta = cc_chequeras.nro_cuenta
                                              and nro_cheque between cc_chequeras.nro_che_inicial and cc_chequeras.ult_che_emitido);
                                              
begin
  --Recorrer chqueras de cuentas gerencia vs registrados en CC_CHE_GER_EMITIDOS
  FOR reg IN cheger LOOP
    BEGIN
        insert into ge_controles (cod_tip_control, nro_cuenta, observacion)
        values (71, reg.nro_cuenta,' Serie: '||reg.serie||' Nro. Che. Inicial: '||reg.nro_che_inicial||' Ult. Che. Emitido: '||reg.ult_che_emitido);
   	END;
	END LOOP;
end lp_che_gerencia;

-- Tarjetas sin relacion en GE_CTA_CLIENTES...................................................72
procedure lp_tar_sin_relacion is
Cursor tarjetas is
select t.nro_cuenta, t.cod_persona, t.nom_embozar
from ta_tarjetas t
where not exists (Select '1'
                   from ge_cta_clientes cc
                  where cc.nro_cuenta = t.nro_cuenta
                    and cc.cod_persona = t.cod_persona
                    and cc.relacion in ('A', 'P') );

begin
  --Recorrer tarjetas que no tienen relacion en GE_CTA_CLIENTES
  FOR reg IN tarjetas LOOP
    BEGIN
        insert into ge_controles (cod_tip_control, nro_cuenta, cod_persona, observacion)
        values (72, reg.nro_cuenta, reg.cod_persona,' Embozado: '||reg.nom_embozar);
   	END;
	END LOOP;
end lp_tar_sin_relacion;

-- Tarjetas con mas de 1 cuenta vigente ......................................................73
procedure lp_tar_mas_vigente is
Cursor tarjetas is
select t.nro_cuenta, t.cod_persona, count(*) cantidad
from ta_tarjetas t
where nvl(t.vigente,'N') = 'S'
group by t.nro_cuenta, t.cod_persona
having count(*) > 1;

begin
  --Recorrer tarjetas con mas de 1 cuenta vigente
  FOR reg IN tarjetas LOOP
    BEGIN
        insert into ge_controles (cod_tip_control, nro_cuenta, cod_persona, observacion)
        values (73, reg.nro_cuenta, reg.cod_persona,' Cantidad: '||reg.cantidad);
   	END;
	END LOOP;
end lp_tar_mas_vigente;

-- Tarjetas activas sin cuentas vigentes........................................................74
procedure lp_tar_sin_vigente is
Cursor tarjetas is
select t.nro_cuenta, t.denominacion, cc.cod_persona, cc.relacion, t.estado
from ge_cta_clientes cc, ta_cta_tarjetas t
where cc.nro_cuenta = t.nro_cuenta
and cc.relacion IN ('A', 'P')
and t.estado != 'C'
and not exists (Select '1'
                from ta_tarjetas x
                where x.nro_cuenta = cc.nro_cuenta
                and x.cod_persona = cc.cod_persona
                and nvl(x.vigente, 'N') = 'S');

begin
  --Recorrer tarjetas sin cuentas vigentes
  FOR reg IN tarjetas LOOP
    BEGIN
        insert into ge_controles (cod_tip_control, nro_cuenta, cod_persona, observacion)
        values (74, reg.nro_cuenta, reg.cod_persona,' Denominacion: '||reg.denominacion||' Relacion: '||reg.relacion||' Estado: '||reg.estado);
   	END;
	END LOOP;
end lp_tar_sin_vigente;

Begin
   pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1;

   delete from ge_controles c where c.cod_tip_control < 1001;
   lp_cuentas_sin_cli_ppal;	  		  --1
   commit;
   lp_ahv;        							 	  --2
   commit;
   lp_con_retenciones;       				--3
   commit;
   lp_con_cj_movimientos;      			--5
   commit;
   lp_con_cli_nex_ge_clientes; 			--6
   commit;
   lp_cuentas_varios_cli_ppal;      --8
   commit;
   lp_ahv_dias_sal_mensuales;  			--9
   commit;
   lp_con_cuentas_clientes;    			--10
   commit;
   lp_con_ge_cuentas;          			--11
   commit;
   lp_con_ge_movimientos;      			--12
   commit;
   lp_con_mae_ge_cuentas;      			--13
   commit;
   lp_con_ofi_ge_movimientos;  			--14
   commit;
   lp_ope_sin_garantias;						--15
   commit;
   lp_con_promotores;          			--16
   commit;
   lp_cda_con_saldos;          			--17
   commit;
   lp_ahv_saldos_vistas;       			--18
   commit;
   lp_con_sal_mensuales;       			--19
   commit;
   lp_con_tip_asientos;        			--21
   commit;
   lp_cda_con_estado_incorrecto;		--22
   commit;
   lp_cda_con_estado_vencido;  			--23
   commit;
   lp_con_dir_duplicado;       			--24
   commit;
   lp_con_extracto;            			--25
   commit;
   lp_cda_sin_cupones;              --26
   commit;
   lp_con_tas_personalizada;    		--28
   commit;
   lp_con_ge_tas_fechas;        		--29
   commit;
   lp_ahv_con_firmas;           		--30
   commit;
   lp_ahv_con_firmantes;        		--31
   commit;
   lp_ctacte_con_firmas;            --32
   commit;
   lp_con_cta_inexistentes;     		--33
   commit;
   lp_con_rel_inexistentes;     		--34
   commit;
   lp_con_dif_firmante4;				 		--38
   commit;
   lp_cda_cupon_monto_cero;				 	--39
   commit;
   lp_cda_cupon_pagado_sin_fecha;	 	--41
   commit;
   lp_cda_saldo_menor_capital;	 		--42
   commit;
   lp_cda_serie_desconocida;				--43
   commit;
   lp_cda_saldo_sin_interes;		 		--44
   commit;
   lp_cda_nro_invalido; 				 		--45
   commit;
   lp_cda_fecha_apertura;			 			--46
   commit;
   lp_cda_sin_beneficiario;		 			--47
   commit;
   lp_cda_ult_vcto_cupon;		 				--48
   commit;
   lp_cda_con_estado_incorrecto2;		--49
   commit;
   lp_ptmo_con_estado_incorrecto;		--50
   commit;
   lp_ptmo_Inicio;								  --51
   commit;
   lp_ptmo_devengado_cuotas;				--52
   commit;
   lp_ptmo_cartera;								  --53
   commit;
   lp_ptmo_adelantado;							--54
   commit;
   lp_ptmo_no_adelantado;						--55
   commit;
   lp_ptmo_adevengar_cuotas;				--56
   commit;
   lp_ptmo_cuo_pago_anticipado;			--57
   commit;
   lp_dif_garantia_detalle;				 	--58
   commit;
   lp_gar_val_vta_rapida;				 	 	--59
   commit;
   lp_che_ord_no_pagos;		 	 	      --60
   commit;
   lp_che_ord_no_pagos1;	 	 	      --61
   commit;
   lp_che_cert;	 	 	                --62
   commit;
   lp_che_cert1; 	 	                --63
   commit;   
   lp_che_anulados;	 	 	            --64
   commit;
   lp_che_anulados1; 	 	            --65
   commit;
   lp_che_pagados;	 	 	            --66
   commit;
   lp_che_pagados1; 	 	            --67
   commit;
   lp_chequera; 	 	                --68
   commit;
   lp_chequera1; 	 	                --69
   commit;
   lp_che_ventanilla; 	 	          --70
   commit;
   lp_che_gerencia; 	 	            --71
   commit;
   lp_tar_sin_relacion;	            --72
   commit;
   lp_tar_mas_vigente; 	            --73
   commit;
   lp_tar_sin_vigente; 	            --74
   commit;
end prg_con_verificaciones;
/

