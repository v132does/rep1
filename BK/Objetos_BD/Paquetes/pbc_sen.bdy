CREATE OR REPLACE PACKAGE BODY IT.PBC_SEN
IS
/*=============================================================
Paquete para el aviso de vencimiento de cupones y certificados.
Baja de Capital de los Bonos Subordinados que correspondan al 
Sistema Electrónico de Negociación (SEN).
=============================================================*/
 v_cod_mon_local         ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
 v_cod_mon_fuerte        ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte; 
 v_ofi_matriz            ge_par_generales.cod_ofi_matriz%TYPE := FUN_OBT_OFI_MATRIZ ;   
 v_fec_actual            DATE := pag_cal.fu_obt_fec_actual(3);
 v_fec_anterior          DATE;
 v_fec_siguiente         DATE;
 v_fec_primera	         DATE;
 v_fec_segunda	         DATE;
 v_fec_tercera	         DATE;
 v_cod_ente              ge_entes.cod_ente%TYPE;
 v_nvo_estado            ah_cta_vistas.estado%TYPE;
 v_sal_disponible        NUMBER:=0;
 v_procesa               VARCHAR2(1) := 'N';
 v_dias                  NUMBER := 1;
 v_cod_mon_anterior      ba_monedas.cod_moneda%TYPE;   
 v_cod_modulo            ba_modulos.cod_modulo%TYPE := 3;
 v_cod_modalidad         ge_modalidades.cod_modalidad%TYPE := 36;
 v_redondeo              number;
 v_conn                  utl_smtp.connection;
 
--==================================================================================================   
PROCEDURE pr_ver_ven_cupones IS
/*
Procedimiento que verifica la fecha de vencimiento de los cupones y certificados de bonos subordinados
*/
  v_tot_tra_mon_local   NUMBER:=0;
  v_tot_tra_mon_fuerte  NUMBER:=0;
  v_can_cup_mon_local   NUMBER:=0;
  v_can_cup_mon_fuerte  NUMBER:=0;	
  v_tot_cap_mon_local   NUMBER:=0;
  v_tot_cap_mon_fuerte  NUMBER:=0;
  v_can_cer_mon_local   NUMBER:=0;
  v_can_cer_mon_fuerte  NUMBER:=0;
  v_dir_cor_tesoreria   ge_par_dinamicos.val_parametro%type;
  v_det_error           ge_ra_log_mail.det_error%type;  
  v_asunto              VARCHAR2(2000);
  v_mje_mail            VARCHAR2(4000);
  v_hor_inicio          ge_log_mail.hor_inicio%type;
  v_hor_fin             ge_log_mail.hor_fin%type;
  v_contador		        NUMBER;
  v_can_dias		        VARCHAR2(100):= NULL;
     
  CURSOR c_cupones(p_fec_anterior IN DATE, p_fec_siguiente IN DATE) IS
     SELECT SUM(acupo.mto_interes)mto_interes,
            upper(accer.cod_moneda) cod_moneda,
            COUNT(*) cantidad,
            acupo.fec_vencimiento       
       FROM ah_cta_certificados accer,
            ah_titulos atitu, 
            ah_cupones acupo
      WHERE accer.ser_titulo = atitu.serie
        AND acupo.fec_vencimiento > p_fec_anterior
        AND acupo.fec_vencimiento <= p_fec_siguiente
        AND accer.nro_titulo = atitu.nro_titulo
        AND accer.estado not in ('A', 'T', 'P', 'C', 'X')            
        AND accer.cod_modalidad = v_cod_modalidad
        AND atitu.ser_origen = 'SEN'
        AND acupo.nro_cuenta = accer.nro_cuenta
        AND acupo.tipo  = accer.tipo
        AND acupo.mto_interes > 0
   GROUP BY upper(accer.cod_moneda),  acupo.fec_vencimiento 
   ORDER BY upper(accer.cod_moneda), acupo.fec_vencimiento;
   
  CURSOR c_certificados(p_fec_anterior IN DATE, p_fec_siguiente IN DATE) IS
	 SELECT SUM(accer.capital) mto_capital,
			    upper(accer.cod_moneda) cod_moneda,
			    COUNT(*) cantidad,
          accer.fec_vencimiento          
	   FROM ah_cta_certificados accer,
			    ah_titulos atitu                
	  WHERE accer.ser_titulo = atitu.serie
      AND accer.fec_vencimiento > p_fec_anterior
		  AND accer.fec_vencimiento <= p_fec_siguiente            
		  AND accer.nro_titulo = atitu.nro_titulo
		  AND accer.estado not in ('A', 'T', 'P', 'C', 'X')
		  AND accer.cod_modalidad = v_cod_modalidad
		  AND atitu.ser_origen = 'SEN'
   GROUP BY upper(accer.cod_moneda), accer.fec_vencimiento
   ORDER BY upper(accer.cod_moneda), accer.fec_vencimiento; 
         
BEGIN
  v_cod_mon_anterior 	:= NULL;      

  FOR v_contador IN 1..2 LOOP  
	
	  IF v_contador = 1 THEN  -- Parametros de cursor para 2 dias habiles
		   v_fec_primera  		:= pag_cal.fu_obt_fec_sig_hab(v_fec_actual, v_ofi_matriz, v_dias);													 
		   v_fec_segunda  		:= pag_cal.fu_obt_fec_sig_hab(v_fec_primera, v_ofi_matriz, v_dias);  
		   v_fec_anterior		  := v_fec_primera;
		   v_fec_siguiente		:= v_fec_segunda;
		   v_can_dias			    := '2(DOS)';
	  ELSIF v_contador = 2 THEN	-- Parametros de cursor para 3 dias habiles
		   v_fec_primera  		:= pag_cal.fu_obt_fec_sig_hab(v_fec_actual, v_ofi_matriz, v_dias);													 
		   v_fec_segunda  		:= pag_cal.fu_obt_fec_sig_hab(v_fec_primera, v_ofi_matriz, v_dias);  
		   v_fec_tercera  		:= pag_cal.fu_obt_fec_sig_hab(v_fec_segunda, v_ofi_matriz, v_dias);  
		   v_fec_anterior		  := v_fec_segunda;
		   v_fec_siguiente		:= v_fec_tercera;
		   v_can_dias			    := '3(TRES)';
	  END IF;
		
	  -- Cursor principal de Cupones --
	  FOR i IN c_cupones(v_fec_anterior,v_fec_siguiente) LOOP                               
		  -- discriminar el total de interes por moneda	 
		  IF i.cod_moneda = v_cod_mon_local THEN
			  v_redondeo          := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, i.cod_moneda);
			  v_tot_tra_mon_local := round(i.mto_interes, v_redondeo);
			  v_can_cup_mon_local := i.cantidad;
			  v_mje_mail          := 'Total a transferir en '||v_cod_mon_local||': '||v_tot_tra_mon_local||'. Cantidad de Cupones: '||v_can_cup_mon_local||'. Fecha de Vencimiento: '||i.fec_vencimiento;
		  ELSIF i.cod_moneda = v_cod_mon_fuerte THEN
			  v_redondeo           := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, i.cod_moneda);
			  v_tot_tra_mon_fuerte := round(i.mto_interes, v_redondeo);
			  v_can_cup_mon_fuerte := i.cantidad;
			  v_mje_mail           := 'Total a transferir en '||v_cod_mon_fuerte|| ': '||v_tot_tra_mon_fuerte||'. Cantidad de Cupones: '||v_can_cup_mon_fuerte||'. Fecha de Vencimiento: '||i.fec_vencimiento;
		  END IF;

		  v_dir_cor_tesoreria := FUG_OBT_PARDINAMICO('DIR_COR_TESORERIA');
			 
		  IF v_dir_cor_tesoreria IS NULL THEN
			 RAISE_APPLICATION_ERROR(-20000, 'Error: no se ha definido ningun valor para el parámetro DIR_COR_TESORERIA.');
		  END IF;

		  -- enviar mail al Dpto. Back de tesoreria (Operativo)   
		  v_det_error    := null;
		  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');

		  v_asunto := 'CUPONES de Bonos Subordinados a vencer dentro de '||v_can_dias||' días hábiles.';
					   
		  BEGIN
			  v_conn := it_mail.begin_mail(fug_obt_dir_correo,v_dir_cor_tesoreria,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
			  it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
				it_mail.end_mail(v_conn);
			EXCEPTION
				when utl_smtp.transient_error or utl_smtp.permanent_error then
					begin
					  utl_smtp.quit(v_conn);
					exception
					when utl_smtp.transient_error or utl_smtp.permanent_error then
					  null;
					end;
					v_det_error := substr(sqlerrm,1,4000);
		  END;
		  
		  v_hor_fin := to_char(sysdate,'hh24:mi:ss');

		  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
		  IF v_det_error is not null THEN			   
        insert into ge_log_mail
         (fec_envio, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
        values
         (sysdate, v_dir_cor_tesoreria, v_asunto, v_det_error, v_hor_inicio, v_hor_fin);     
        commit;
		  END IF;
	  
	  END LOOP; -- Fin de cursor de cupones
	   
	-- Cursor principal de Certificados --
	  FOR i IN c_certificados(v_fec_anterior,v_fec_siguiente) LOOP                               
		 -- discriminar el total de capital por moneda	 
		  IF i.cod_moneda = v_cod_mon_local THEN
			  v_redondeo          := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, i.cod_moneda);
			  v_tot_cap_mon_local := round(i.mto_capital, v_redondeo);
			  v_can_cer_mon_local := i.cantidad;
			  v_mje_mail          := 'Total a transferir en '||v_cod_mon_local||': '||v_tot_cap_mon_local||'. Cantidad de Certificados: '||v_can_cer_mon_local||'. Fecha de Vencimiento: '||i.fec_vencimiento;
		  ELSIF i.cod_moneda = v_cod_mon_fuerte THEN
			  v_redondeo           := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, i.cod_moneda);
			  v_tot_cap_mon_fuerte := round(i.mto_capital, v_redondeo);
			  v_can_cer_mon_fuerte := i.cantidad;
			  v_mje_mail           := 'Total a transferir en '||v_cod_mon_fuerte|| ': '||v_tot_cap_mon_fuerte||'. Cantidad de Certificados: '||v_can_cer_mon_fuerte||'. Fecha de Vencimiento: '||i.fec_vencimiento;
		  END IF;

		  v_dir_cor_tesoreria := FUG_OBT_PARDINAMICO('DIR_COR_TESORERIA');
			 
		  IF v_dir_cor_tesoreria IS NULL THEN
			   RAISE_APPLICATION_ERROR(-20000, 'Error: no se ha definido ningun valor para el parámetro DIR_COR_TESORERIA.');
		  END IF;

		  -- enviar mail al Dpto. Back de tesoreria (Operativo)   
		  v_det_error    := null;
		  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');

		  v_asunto := 'CERTIFICADOS de Bonos Subordinados a vencer dentro de '||v_can_dias||' días hábiles.';
					   
		  BEGIN
			  v_conn := it_mail.begin_mail(fug_obt_dir_correo,v_dir_cor_tesoreria,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
			  it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
				it_mail.end_mail(v_conn);
			EXCEPTION
				when utl_smtp.transient_error or utl_smtp.permanent_error then
					begin
					  utl_smtp.quit(v_conn);
					exception
					when utl_smtp.transient_error or utl_smtp.permanent_error then
					  null;
					end;
					v_det_error := substr(sqlerrm,1,4000);
		  END;
		  
		  v_hor_fin := to_char(sysdate,'hh24:mi:ss');

		  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
		  IF v_det_error is not null THEN			   
        insert into ge_log_mail
         (fec_envio, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
        values
         (sysdate, v_dir_cor_tesoreria, v_asunto, v_det_error, v_hor_inicio, v_hor_fin);     
        commit;
		  END IF;
	  
	  END LOOP; -- Fin de cursor de certificados
	  
  END LOOP; -- Fin de ciclo
	
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000, 'Error General: PR_VER_VEN_CUPONES: ' || SQLERRM);
END;
   

--==================================================================================================
PROCEDURE pr_cre_aut_bonos IS 
  /*
  Pago de Capital para la modalidad 36/Bonos Subordinados.
  */
  v_nro_secuencia  ge_movimientos.nro_secuencia%TYPE := 0;/*solo inicializar aqui*/  
  v_hora           ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss'); 
  v_est_modulo     ba_modulos.estado%type := pae_cnf.FU_OBT_EST_MODULO(3);
  v_es_nocturno    varchar2(1) := 'N';
  
  CURSOR c_bonos IS
     SELECT accer.nro_cuenta,
            accer.nro_certificado,
            accer.cod_oficina,
            accer.cod_moneda,
            accer.capital,
            accer.nro_cta_credito
       FROM ah_cta_certificados accer, ah_titulos atitu
      WHERE accer.estado = 'V'
        AND accer.est_certificado = 'V'
        AND accer.ser_titulo = atitu.serie
        AND accer.nro_titulo = atitu.nro_titulo
        AND atitu.ser_origen = 'SEN'
        AND accer.cod_modalidad = v_cod_modalidad
		AND accer.nro_cta_credito is not null;
BEGIN
  v_cod_mon_anterior := NULL;
  --Para obtener el ente para insertar en el movimiento--
  BEGIN
	  SELECT cod_ente
	    INTO v_cod_ente
	    FROM ge_entes
	   WHERE tipo = 'BO';
  EXCEPTION
	 WHEN NO_DATA_FOUND THEN
		 RAISE_APPLICATION_ERROR(-20000, 'Sin datos para el Ente de Bonos');
	 WHEN too_many_rows THEN
		 RAISE_APPLICATION_ERROR(-20000, 'Mas de un Ente para Bonos');
	 WHEN OTHERS THEN
		 RAISE_APPLICATION_ERROR(-20000, 'Error Obt.Ente p/Bonos:' || SQLERRM);
  END;
  
  -- RABP-CNF 22/01/2015 - Verifica si el movimiento es Nocturno 
  If v_est_modulo = 2 then
     v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
  else
     v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
  end if;
  -- RABP-CNF 22/01/2015 - Asigna la Hora Disponible actual
  v_hora  := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno); 
   --
      
  FOR i IN c_bonos LOOP 

    IF i.cod_moneda <> NVL(v_cod_mon_anterior,-1) THEN
       v_cod_mon_anterior := i.cod_moneda;         
       IF i.cod_moneda not in (v_cod_mon_local, v_cod_mon_fuerte) THEN
          RAISE_APPLICATION_ERROR(-20000, 'Moneda no definida');
       END IF;
    END IF;
    
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, i.cod_moneda);
          
    pag_cta.pr_obt_cuenta(i.nro_cuenta );   
    pag_cta.pr_ver_operacion(i.nro_cuenta, 329, v_cod_modulo, v_cod_modalidad, 'D',
                             i.cod_moneda,
                             round(i.capital, v_redondeo),
                             i.cod_oficina,
                             pag_cta.g_ctas.cod_modulo,
                             pag_cta.g_ctas.cod_modalidad,
                             v_nvo_estado, v_sal_disponible,
                             v_procesa);

    IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
       RAISE_APPLICATION_ERROR(-20000, 'Error Ver.Cta.Débito ' || i.nro_cuenta || '-' ||pag_cta.g_msj_error);
    END IF;

    IF v_procesa = 'S' THEN      
  	 
       if nvl(v_nro_secuencia, 1) >= 995 then
         v_hora  := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno); 
         v_nro_secuencia := -999;
       else
         v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
       end if;

       /*********************************
       || Debita de la cuenta del Ente
       *********************************/
       -- Actualiza la Cuenta Bonos / Débito
       pag_cta.pr_act_operacion(i.nro_cuenta,
                                v_hora,
                                'D',
                                i.cod_moneda,
                                round(i.capital, v_redondeo),
                                329,
                                503,
                                i.nro_certificado,
                                NULL,  --COTIZACION
                                i.cod_oficina,
                                v_cod_modulo,
                                v_cod_modalidad,
                                NULL,  --cod_tasa
                                NULL,  --val_tasa
                                'Débito Cuenta Nro. Certificado:' || i.nro_certificado||'. (Capital Bonos).',
                                'S',
                                v_nro_secuencia,
                                v_fec_actual,
                                NULL,
                                NULL,
                                i.capital);
       IF pag_cta.g_cod_error <> 0 THEN
          RAISE_APPLICATION_ERROR(-20000, 'Error Act.Operación.Cta.Debito ' || i.nro_cuenta || '-' ||pag_cta.g_msj_error);
       ELSE 
           /*********************************
           || Acredita en la cuenta de Crédito (Suspenso)
           *********************************/
           pag_cta.pr_act_operacion(i.nro_cta_credito,
                                    v_hora, --HORA
                                    'C',
                                    i.cod_moneda, --Moneda de la Operación
                                    round(i.capital, v_redondeo),
                                    329,
                                    602, --COD_TRA_HIJO (602)
                                    i.nro_certificado,
                                    NULL, --COTIZACION
                                    i.cod_oficina, --cod_ofi_origen
                                    v_cod_modulo, --cod_mod_padre   
                                    v_cod_modalidad, --cod_mad_padre
                                    null, --cod_tasa
                                    null, --val_tasa
                                    'Crédito automático de Cuenta Nro. Certificado:' || i.nro_certificado||'. (Capital Bonos).',
                                    'S', --emi_aviso
                                    v_nro_secuencia,
                                    v_fec_actual,
                                    NULL,
                                    NULL,
                                    i.capital);
    
            if pag_cta.fu_obt_cod_error() <> 0 then
              --Actualizacion con problemas
              raise_application_error(-20001,
                                      'Act. Pag. Capital a Cta. ' || i.nro_cuenta || '-' ||
                                      pag_cta.fu_obt_cod_error() || '-' ||
                                      pag_cta.fu_obt_msj_error());
            end if;    
       END IF;
    ELSE
       RAISE_APPLICATION_ERROR(-20000, 'Error: Cta.' || i.nro_cuenta ||'- Sin saldo suficiente para el Débito');
    END IF;
                           
 END LOOP;
  
EXCEPTION
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error General: pbc_sen.PR_CRE_AUT_BONOS: ' || SQLERRM);
END;   
   
   --==================================================================================================
   
END PBC_SEN;
/

