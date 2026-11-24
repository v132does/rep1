CREATE OR REPLACE PROCEDURE IT.PRT_INS_COB_PRONET IS
  /*
    Inserta los datos en la tabla GE_MOV_PRO_COBRANZAS. 
	Manualmente es ejecutado desde la pantalla Importador de Datos GMPROARC.-
  */

  r_reg               GE_MOV_PRO_COBRANZAS%ROWTYPE;
  c_fec_proceso       GE_MOV_PRO_COBRANZAS.FECHA%TYPE;
  c_cantidad          GE_MOV_PRO_COBRANZAS.CANT_REGISTROS%TYPE;
  c_tot_registro      VARCHAR2(15);
  c_observacion       GE_MOV_PRO_COBRANZAS.OBSERVACION%TYPE;
  c_nro_cta_debito    GE_MOV_PRO_COBRANZAS.NRO_CTA_DEBITO%TYPE  := fug_obt_pardinamico('CTA_DEB_PRONET');
  v_existe			      VARCHAR2(1);
  -- variables para el log de errores --
  r_log               TA_LOG_PRONET%ROWTYPE;
  v_registro          NUMBER(4) := 0;
  v_error             BOOLEAN := TRUE;
  v_lote              TA_LOG_PRONET.NRO_LOTE%TYPE := 0;
  v_boleta            TA_LOG_PRONET.NRO_BOLETA%TYPE := 0;
  v_tarjeta           TA_LOG_PRONET.NRO_TARJETA%TYPE := 'X'; 
  
  -- Variables para envio de mail --
  v_fec_actual   DATE          := pag_cal.FU_OBT_FEC_ANTERIOR(5);
  c_env_mail     VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com';
  c_rec_mail     VARCHAR2(100) := fug_obt_pardinamico('DIR_IMP_PRONET');    
  c_asunto       VARCHAR2(400) ;
  c_mensaje      VARCHAR2(4000);
  v_nom_archivo  VARCHAR2(200) := 'clearingBBVA'|| to_char(v_fec_actual,'DDMMYY')||'.txt';
  
  Cursor Datos is
      -- Extraemos el detalle del archivo
      Select  a.nro_tarjeta,
              b.nro_cuenta,
              b.cod_moneda,
              to_char(to_date(substr(c.datos,9,8),'yyyy/mm/dd'),'dd/mm/yyyy') fec_pago,
              to_number(substr(c.datos,17,6))                                 nro_lote,
              to_number(substr(c.datos,23,6))                                 nro_boleta,
              to_char(substr(c.datos,59,12)||','||substr(c.datos,71,2))       importe,
              fug_obt_des_transaccion(b.cod_modulo, b.cod_modalidad, fug_obt_pardinamico('TRA_COB_PRONET')) desc_trans
         From ta_tarjetas a, ta_cta_tarjetas b, ta_cob_tmp_pronet c
        Where length(c.datos) <> 30 -- Cantidad de caracteres que tiene la cabecera
          and a.nro_cuenta  = b.nro_cuenta
          and a.nro_tarjeta = to_number(substr(c.datos,29,30))
          and not exists(Select 1
                         From GE_MOV_PRO_COBRANZAS ax
                         Where ax.nro_lote   = to_number(substr(c.datos,17,6))
                           and ax.nro_boleta = to_number(substr(c.datos,23,6))
                           and ax.fecha_pago = to_char(to_date(substr(c.datos,9,8),'yyyy/mm/dd'),'dd/mm/yyyy')); -- DYDMR-70. CB. 24/04/2014
                           
-- Funcion para convertir un string en numero ----------------
FUNCTION obt_numero(P_NUM IN VARCHAR2) RETURN NUMBER  AS
  v_nro NUMBER;
  v_a   VARCHAR2(25);
BEGIN
	select to_number(p_num) into v_nro from dual;
  return v_nro;
EXCEPTION
  WHEN OTHERS THEN
      v_a := replace(p_num, ',','.');
      v_nro := to_number(v_a);
      return v_nro;
END;

-- Procedimiento para insertar datos en la tabla GE_MOV_PRO_COBRANZAS ----------------
PROCEDURE PR_INS_COB_PRONET
 (rp_gmovi IN GE_MOV_PRO_COBRANZAS%ROWTYPE
 )
 IS

 BEGIN
      insert into GE_MOV_PRO_COBRANZAS(FECHA          ,
                                         HORA           ,
                                         NRO_BOLETA     ,
                                         COD_MONEDA     ,
                                         MONTO          ,
                                         NRO_CTA_DEBITO ,
                                         NRO_CTA_CREDITO,
                                         OBSERVACION    ,
                                         NRO_TARJETA    ,
                                         NRO_LOTE       ,
                                         FECHA_PAGO     ,
                                         CANT_REGISTROS ,
                                         TOT_IMPORTE    )
                                 values (rp_gmovi.fecha          ,
                                         rp_gmovi.hora           ,
                                         rp_gmovi.nro_boleta     ,
                                         rp_gmovi.cod_moneda     ,
                                         rp_gmovi.monto          ,
                                         rp_gmovi.nro_cta_debito ,
                                         rp_gmovi.nro_cta_credito,
                                         rp_gmovi.observacion    ,
                                         rp_gmovi.nro_tarjeta    ,
                                         rp_gmovi.nro_lote       ,
                                         rp_gmovi.fecha_pago     ,
                                         rp_gmovi.cant_registros ,
                                         rp_gmovi.tot_importe    );
exception
  when others then
       raise_application_error(-20000,'insertar en '||SQLERRM||' usuario '||substr(lower(user),1,6)||
                               ' fecha  '||to_char(rp_gmovi.fecha)||' hora '||rp_gmovi.hora);

END;


-- Procedimiento para modificar los nros de tarjeta(Citi) que no existen, por su equivalente del BBVA  -------------
PROCEDURE PR_MOD_TMP_PRONET IS
	Cursor Tarjetas is
	  select distinct substr(p.datos,29,30) nro_tarj
	    from ta_cob_tmp_pronet p 
	   where length(p.datos) > 30 -- descartamos la cabecera
	     and not exists (select 1 
                         from ta_tarjetas m
                        where m.nro_tarjeta = to_number(substr(p.datos,29,30))
                       );     
  c_tar_bbva		VARCHAR2(30);
  c_cli_bbva		VARCHAR2(30) := fug_obt_pardinamico('NRO_TAR_GENERICA');
  c_dominio     VARCHAR2(15) := 'EQU_CITI_BBVA';
  b_generico		BOOLEAN   := FALSE; 

BEGIN
	FOR t IN Tarjetas LOOP	
		BEGIN
			-- Buscamos el nro de tarjeta BBVA equivalente
			select lpad(r.val_maximo,30,'0') 
			  into c_tar_bbva
			  from ba_cod_referencias r 
			 where r.dominio    = c_dominio
			   and r.val_minimo = to_number(t.nro_tarj);
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				-- Al no existir asignamos el nro de tarjeta del cliente BBVA,PARAGUAY (cta:102160001)
			  c_tar_bbva := c_cli_bbva;
			  b_generico := TRUE;		  
		END;
		
		-- Modificamos en la tabla temporal los datos
		update ta_cob_tmp_pronet p
		   set p.datos = substr(p.datos,1,28)||c_tar_bbva||substr(p.datos,59,3940)                                 
		 where substr(p.datos,29,30) = t.nro_tarj;
	END LOOP;
commit;

	IF b_generico = TRUE THEN
		c_asunto := 'Asignacion de Numero de TDC Generica en archivo '||v_nom_archivo;
		c_mensaje := 'Se asigno el numero de tarjeta generico '||c_cli_bbva||' al/los registro/s de pagos de Pronet de fecha '||c_fec_proceso||'.'||chr(13)||'Nombre del archivo: '||v_nom_archivo;
		PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje);
	END IF;
  
EXCEPTION
	WHEN OTHERS THEN
	   RAISE_APPLICATION_ERROR(-20000,'Modificar nro tarjeta Citi por el de BBVA - '||SQLERRM);
END;

-- BLOQUE PRINCIPAL --
BEGIN
      -- Datos para cargar en el logs de errores de ser necesario
      r_log.nom_proceso := 'PRT_INS_COB_PRONET';
      r_log.fec_envio   := to_char(sysdate,'DD/MM/YYYY');
      r_log.hor_envio   := to_char(sysdate,'hh24:mm:ss');

      -- Extraemos la cabecera del archivo
      Begin
          v_registro := v_registro + 1;
          
          select to_date(substr(c.datos,1,8),'yyyy/mm/dd') fec_proceso,
                 to_number(substr(c.datos,9,8)) cantidad,
                 to_char(substr(c.datos,17,12)||','||substr(c.datos,29,2))imp_total
            into c_fec_proceso, c_cantidad, c_tot_registro
            from ta_cob_tmp_pronet c
           where length(c.datos) = 30;  -- Cantidad de datos que debe tener la cabecera
      Exception
           When others then
                raise_application_Error(-20000,'Error al Insertar Cabecera '||sqlerrm);
      End;
	  
      -- Verificamos que los numeros de tarjetas del Citi existan en el Core Bancario
      Begin
        select distinct 'S'
          into v_existe
          from ta_cob_tmp_pronet p
         where length(p.datos) > 30 -- descartamos la cabecera
           and not exists(select 1
                            from ta_tarjetas m
                           where m.nro_tarjeta = to_number(substr(p.datos, 29, 30))
                          );                  
      Exception
        when no_data_found then
          v_existe := 'N';                    
      End;
      IF v_existe = 'S' THEN
        -- Ejecutamos el procedimiento para modificar los numeros de tarjeta
        PR_MOD_TMP_PRONET;
      END IF;
	  
      For i in datos loop
        
          v_registro := v_registro + 1;
          v_lote     := i.nro_lote;
          v_boleta   := i.nro_boleta;
          v_tarjeta  := i.nro_tarjeta;

          c_observacion := 'Boleta: '||i.nro_boleta||'. Trans: '||i.desc_trans||'. Lote: '||i.nro_lote||'. Fecha Pago'||i.fec_pago;

          r_reg.fecha           := c_fec_proceso;
          r_reg.hora            := to_char(sysdate,'HH24:MM:SS');
          r_reg.nro_boleta      := i.nro_boleta;
          r_reg.cod_moneda      := i.cod_moneda;
          r_reg.monto           := obt_numero(i.importe);
          r_reg.nro_cta_debito  := c_nro_cta_debito;
          r_reg.nro_cta_credito := i.nro_cuenta;
          r_reg.observacion     := substr(c_observacion,1,100);
          r_reg.nro_tarjeta     := i.nro_tarjeta;
          r_reg.nro_lote        := i.nro_lote;
          r_reg.fecha_pago      := i.fec_pago;
          r_reg.cant_registros  := c_cantidad;
          r_reg.tot_importe     := obt_numero(c_tot_registro);
          PR_INS_COB_PRONET(R_REG);

      End Loop;
	commit;
EXCEPTION
      when others then
           IF v_registro = 1  THEN
              r_log.nro_lote    := 1;
              r_log.nro_boleta  := 1;
              r_log.nro_tarjeta := '1';
           ELSE
              r_log.nro_lote    := v_lote;
              r_log.nro_boleta  := v_boleta;
              r_log.nro_tarjeta := v_tarjeta;
           END IF;
           r_log.comentario := substr( 'Error al insertar datos del archivo de Cobro TC Pronet en la tabla maestra ' || c_fec_proceso||'. '||DBMS_UTILITY.format_error_backtrace,1,4000);
           r_log.nro_linea  := v_registro;
           PRT_INS_LOG_PRONET(r_log,v_error);
		       c_asunto  := 'Error durante importacion de pagos Pronet a la tabla maestra. Fecha '||v_fec_actual;
		       c_mensaje := 'Error en la importacion de los registros de pagos de Pronet a la tabla maestra, en la fecha '||v_fec_actual||'.'||chr(13)||'Nombre del archivo: ';
           PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
END PRT_INS_COB_PRONET;
/

