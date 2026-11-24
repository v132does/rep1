CREATE OR REPLACE PROCEDURE IT.PRG_GEN_DAT_EXT_SEMESTRAL (p_semestre varchar2, p_ano varchar2) IS
  v_fec_desde date;
  v_fec_hasta date;
  v_msj	varchar2(4000);
  v_fec_actual date := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
  v_des_fecha 			ge_inf_semestral.des_fecha%type;
  v_can_cta_tarjetas number;
  v_tip_extracto varchar2(1);
  v_cod_gru_transaccion ge_gru_transacciones.cod_gru_transaccion%type := fug_obt_pardinamico('GRU_TRA_EXC_TRA_INFSEM');
  CURSOR cu_clientes
      IS SELECT distinct b.cod_oficina, v.cod_persona, c.nom_completo nom_completo, a.nom_entidad,
                b.telefono tel_oficina, v.cod_moneda, c.tipo, c.nro_documento,
                fue_obt_dat_personas(v.cod_persona, 'RUC') nro_ruc,
	              fue_obt_dat_personas(v.cod_persona, 'DIR') direccion,
	              fue_obt_dat_personas(V.cod_persona, 'TEL') telefono,
	              d.direccion ||' - '||fue_obt_titulo(d.descripcion)||' - Py.' dir_matriz,
	              b.direccion ||' - '||fue_obt_titulo(b.descripcion)||' - Py.' dir_oficina,
	              fug_es_empleado(v.cod_persona) ind_funcionario,
	              fug_es_cli_nomina(v.cod_persona) ind_nomina,
	              fue_obt_dat_personas(v.cod_persona, 'WEB') ind_web,
                cl.tip_extracto
				   FROM cb_lib_ventas v, ba_personas c, ba_oficinas d, ba_oficinas b, ge_par_generales a, ge_clientes cl
 					WHERE v.fecha between v_fec_desde and v_fec_hasta
 					  and d.cod_oficina = a.cod_ofi_matriz
   					and v.cod_persona = c.cod_persona
 						and v.cod_persona = cl.cod_persona
   					and b.cod_oficina = cl.cod_oficina
   					and b.estado = 'A';
   TYPE cursor1_type IS TABLE OF cu_clientes%ROWTYPE;
   c cursor1_type;
BEGIN
	v_des_fecha := fug_des_fecha(v_fec_actual);

  if p_semestre ='P' then
		v_fec_desde:= '01/01/'||to_char(p_ano);
		v_fec_hasta:= '30/06/'||to_char(p_ano);
  else
		v_fec_desde:= '01/07/'||to_char(p_ano);
		v_fec_hasta:= '31/12/'||to_char(p_ano);
  End if;

  sql_util.ejecute_dml( 'truncate table ge_inf_semestral', v_msj );
  IF v_msj IS NOT NULL THEN
  	raise_application_error(-20000,v_msj);
  END IF;

  sql_util.ejecute_dml( 'truncate table ge_inf_semestral_det', v_msj );
  IF v_msj IS NOT NULL THEN
  	raise_application_error(-20000,v_msj);
  END IF;

  OPEN cu_clientes;
  LOOP
  FETCH cu_clientes BULK COLLECT INTO c LIMIT 3000;
	  FOR i IN 1 .. c.count LOOP
      if c(i).tipo = 'F' then
        if c(i).tip_extracto = 'N' then
           v_tip_extracto := 'N';
        else 
           begin
             select count(t.nro_cuenta)
               into v_can_cta_tarjetas
               from ge_cta_clientes c, ta_cta_tarjetas t, ge_cta_dat_adicionales d
              where c.cod_persona = c(i).cod_persona
                and c.relacion = 'P'
                and c.nro_cuenta = t.nro_cuenta
                and c.nro_cuenta = d.nro_cuenta
                and d.parametro = 'RET_EXTRACTO'
                and d.val_parametro = 'S';
           exception 
             when others then
               v_can_cta_tarjetas := 0;
           end;
           if nvl(v_can_cta_tarjetas, 0) > 0 then
              v_tip_extracto := 'N';
           else
              v_tip_extracto := 'S';
           end if;
        end if;
      else
        v_tip_extracto := 'S';
      end if;
      
	    BEGIN
		  	insert into ge_inf_semestral ( semestre,
		                                   ano,
		                                   cod_oficina,
		                                   cod_persona,
		                                   des_fecha,
                                       nro_ruc,
                                       nom_completo,
                                       direccion,
                                       telefono,
                                       nom_entidad,
                                       ruc_entidad,
                                       matriz,
                                       dir_oficina,
                                       tel_oficina,
                                       cod_moneda,
                                       tip_persona,
                                       ind_funcionario,
                                       ind_nomina,
                                       ind_web,
                                       tip_extracto)
                                values (p_semestre,
                                        p_ano,
                                        c(i).cod_oficina,
                                        c(i).cod_persona,
                                        v_des_fecha,
                                        c(i).nro_ruc,
                                        c(i).nom_completo,
                                        c(i).direccion,
                                        c(i).telefono,
                                        c(i).nom_entidad,
                                        'RUC ' ||c(i).nro_documento,
                                        c(i).dir_matriz,
                                        c(i).dir_oficina,
                                        c(i).tel_oficina,
                                        c(i).cod_moneda,
                                        c(i).tipo,
                                        c(i).ind_funcionario,
                                        c(i).ind_nomina,
                                        c(i).ind_web,
                                        c(i).tip_extracto);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, 'No se puede insertar la cabecera del extracto de la persona. '||c(i).cod_persona||'. '||sqlerrm);
    END;

    BEGIN
        insert into ge_inf_semestral_det ( semestre,
                                           ano,
                                           cod_persona,
                                           nro_item,
                                           cantidad,
                                           descripcion,
                                           precio,
                                           mto_exento,
                                           mto_gra_5,
                                           mto_gra_10,
                                           nro_factura,
                                           nro_timbrado,
                                           nro_cuenta,
                                           fecha,
                                           tip_comprobante,
                                           nro_fac_referencia,
                                           cod_transaccion,
                                           cod_modulo,
                                           cod_modalidad,
                                           ind_interes)
        (select p_semestre,p_ano, a.cod_persona,rownum,  1 cantidad,
                fue_obt_titulo(b.descripcion) descripcion,
                (nvl(b.mto_exento_gs,0) + nvl(b.mto_gra_5_gs,0) + nvl(b.mto_gra_10_gs,0)+nvl(b.impuesto_5_gs,0)+nvl(b.impuesto_10_gs,0)) precio,
                decode(a.tip_comprobante,'N', nvl(b.mto_exento_gs,0)*-1, nvl(b.mto_exento_gs,0))  mto_exento,
                decode(a.tip_comprobante,'N', (nvl(b.mto_gra_5_gs,0)+nvl(b.impuesto_5_gs,0))*-1, (nvl(b.mto_gra_5_gs,0)+nvl(b.impuesto_5_gs,0)))   mto_gra_5,
                decode(a.tip_comprobante,'N', (nvl(b.mto_gra_10_gs,0)+nvl(b.impuesto_10_gs,0))*-1,(nvl(b.mto_gra_10_gs,0)+nvl(b.impuesto_10_gs,0))) mto_gra_10,
                a.nro_factura,
                a.nro_timbrado,
                b.nro_cuenta,
                b.fecha,
                a.tip_comprobante,
                decode(a.tip_comprobante,'F',trim(b.nro_documento),A.NRO_FAC_REFERENCIA)  nro_documento,
                b.cod_transaccion, b.cod_modulo, b.cod_modalidad,
                FUE_OBT_TRA_INTERES(B.COD_TRANSACCION,B.COD_MODULO,B.COD_MODALIDAD) INTERES
           from cb_lib_ventas a, cb_lib_ventas_det b
          where a.fecha between v_fec_desde and v_fec_hasta
            and a.nro_factura = b.nro_factura
            and a.nro_timbrado = b.nro_timbrado
            and a.cod_persona=c(i).cod_persona
            and not exists (select 1 from ge_gru_transacciones_det
                            where cod_gru_transaccion = v_cod_gru_transaccion
                              and cod_modulo = b.cod_modulo
                              and cod_modalidad = b.cod_modalidad
                              and cod_transaccion = b.cod_transaccion ));
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'No se puede insertar el detalle del extracto de la persona. '||c(i).cod_persona||'. '||sqlerrm);
      END;

    END LOOP;
    commit;
    EXIT WHEN cu_clientes%NOTFOUND;
  END LOOP;
exception
 when others then
   raise_application_error(-20000,'Error al cargar los datos del Extracto Semestral. '||sqlerrm);
END;
/

