CREATE OR REPLACE PROCEDURE it.prs_gen_acciones IS
---Proceso de generación archivo Sociedades Circular 218
  v_fec_anterior      ge_calendarios.fec_anterior%type;
  v_cliente           ba_personas.cod_persona%type;
  v_cta_activa        varchar2(1);
  rp_scta             sb_bcp_acciones%ROWTYPE;
  v_ind_acc           ba_acc_portador.ind_acc_portador%type;
  v_informado         varchar2(1);
  v_lugar             varchar2(300) := null;
-- funcion que verifica la existencia del informe anterior
   FUNCTION lf_ver_estado
   (
      p_cod_persona sb_bcp_acciones.cod_persona%TYPE       
   ) RETURN VARCHAR2 IS
      v_estado VARCHAR2(1) default 'N';
   BEGIN
     begin                
        select c.estado
          INTO v_estado 
          from sb_bcp_acciones c where c.cod_persona=p_cod_persona 
                               and c.fecha= (select max(fecha) from sb_bcp_acciones cc where cc.cod_persona=p_cod_persona);                                         
      exception
        when no_data_found then
            v_estado := 'N';             
      end;
   return v_estado;      
   END;
   
 PROCEDURE lp_obt_dat_cliente
   (
      p_cod_persona          IN VARCHAR2,
      p_tip_documento        IN OUT VARCHAR2,
      p_nro_documento        IN OUT VARCHAR2,
      p_cod_moneda           IN OUT VARCHAR2,
      p_cap_suscrito         IN OUT NUMBER,
      p_cap_integrado        IN OUT NUMBER,
      p_can_acc_portador     IN OUT NUMBER,
      p_can_acc_nominativa   IN OUT NUMBER,
      p_ind_acc              IN OUT VARCHAR2)      
   IS  
   BEGIN      
      SELECT decode(t.abreviatura, 'DNI', 'CRC', 'PAS', 'CRC', 'SW', 'CRC', 'OTR', 'CRC', 'PJ', 'CRC',
                    t.abreviatura) tip_documento,c.nro_documento,pas_cri.fu_obt_mon_iso(b.cod_moneda),b.cap_suscrito,b.cap_integrado,
        b.can_acc_portador,b.can_acc_nominativa,b.ind_acc_portador
        INTO p_tip_documento, p_nro_documento, p_cod_moneda,p_cap_suscrito,p_cap_integrado,p_can_acc_portador,p_can_acc_nominativa,
             p_ind_acc
        FROM ba_acc_portador b, ba_personas c, ba_tip_documentos t
        WHERE b.cod_persona=c.cod_persona
        AND t.cod_tip_documento=c.cod_tip_documento
        and c.cod_persona=p_cod_persona;      
   EXCEPTION
      WHEN OTHERS THEN
         p_tip_documento := NULL;
   END; 
 PROCEDURE lp_obt_dat_sociedades
   (
      p_cod_persona          IN VARCHAR2,
      p_tip_doc_eli          IN OUT VARCHAR2,
      p_nro_doc_eli          IN OUT VARCHAR2,
      p_cod_mon_eli          IN OUT VARCHAR2,
      p_cap_sus_eli          IN OUT NUMBER,
      p_cap_int_eli          IN OUT NUMBER,
      p_can_acc_por_eli      IN OUT NUMBER,
      p_can_acc_nom_eli   IN OUT NUMBER)      
   IS  
   BEGIN      
      SELECT b.tip_documento ,b.nro_documento,b.cod_moneda,b.cap_suscrito,b.cap_integrado,
        b.can_acc_portador,b.can_acc_nominativa
        INTO p_tip_doc_eli, p_nro_doc_eli, p_cod_mon_eli,p_cap_sus_eli,p_cap_int_eli,p_can_acc_por_eli,p_can_acc_nom_eli
        FROM sb_bcp_acciones b
        WHERE b.cod_persona=p_cod_persona
        AND b.fecha= (select max(fecha) from sb_bcp_acciones p where p.cod_persona=b.cod_persona);      
   EXCEPTION
      WHEN OTHERS THEN
         p_nro_doc_eli := NULL;
   END;        
PROCEDURE lp_ins_sociedades(rp_scta sb_bcp_acciones%ROWTYPE) IS   
   BEGIN      
         INSERT INTO sb_bcp_acciones
            (fecha, nro_formulario, tip_documento, nro_documento, cod_moneda, cap_suscrito, cap_integrado, can_acc_portador, 
             can_acc_nominativa, estado, cod_persona)
         VALUES
            (rp_scta.fecha,rp_scta.nro_formulario,rp_scta.tip_documento,rp_scta.nro_documento,rp_scta.cod_moneda,rp_scta.cap_suscrito,
            rp_scta.cap_integrado,rp_scta.can_acc_portador,rp_scta.can_acc_nominativa,rp_scta.estado,rp_scta.cod_persona
            );
            
       update ba_acc_portador g set g.informado='S' 
        where g.cod_persona=rp_scta.cod_persona;      
   END;

PROCEDURE pr_inf_altas        
   IS
 v_inf_alta varchar2(1):='N';
 v_tip_documento sb_bcp_acciones.tip_documento%TYPE;
 v_nro_documento sb_bcp_acciones.nro_documento%TYPE;
 v_cod_moneda    sb_bcp_acciones.cod_moneda%TYPE;
 v_cap_suscrito  sb_bcp_acciones.cap_suscrito%TYPE;
 v_cap_integrado sb_bcp_acciones.cap_integrado%TYPE;
 v_can_acc_portador sb_bcp_acciones.can_acc_portador%TYPE;
 v_can_acc_nominativa   sb_bcp_acciones.can_acc_nominativa%TYPE;
 v_modificado varchar2(1):='N';
 ---cursor para altas de sociedades 
 CURSOR alt_soc IS
    SELECT t.cod_persona
     FROM ba_acc_portador t
     WHERE nvl(t.informado,'N')='N';
---cursor para cuentas activas
  CURSOR cuentas IS
         select 'S' v_cta_activa,cl.cod_persona
           from ge_est_cuentas es,
                ba_modulos mo,
                ge_modalidades ma,
                ge_cuentas c,
                ge_cta_clientes cc,
                ge_clientes cl
          where es.cod_modulo = c.cod_modulo
            and es.cod_modalidad = c.cod_modalidad
            and es.estado = c.estado
            and es.activo = 'S'
            and ma.cod_modalidad = cc.cod_modalidad
            and ma.cod_modulo = cc.cod_modulo
            and mo.cod_modulo = cc.cod_modulo
            and c.cod_modulo = cc.cod_modulo
            and c.cod_modalidad = cc.cod_modalidad
            and c.nro_cuenta = cc.nro_cuenta
            and cl.cod_persona=cc.cod_persona
            and cc.relacion='P'
            and cc.cod_persona = v_cliente
            and rownum=1;   
BEGIN        
     FOR soc IN alt_soc LOOP
      v_cliente    := soc.cod_persona;
      FOR cta IN cuentas  LOOP
        if nvl(cta.v_cta_activa,'N')='S' then
         v_inf_alta:=  lf_ver_estado(v_cliente);
         lp_obt_dat_cliente(v_cliente,rp_scta.tip_documento,rp_scta.nro_documento, rp_scta.cod_moneda,rp_scta.cap_suscrito,rp_scta.cap_integrado,rp_scta.can_acc_portador,rp_scta.can_acc_nominativa,v_ind_acc);      
         rp_scta.fecha:= v_fec_anterior;
         rp_scta.nro_formulario:='015';
         if v_inf_alta='A' or v_inf_alta='M' then
           rp_scta.estado:='M';
           lp_obt_dat_sociedades(v_cliente,v_tip_documento,v_nro_documento, v_cod_moneda,v_cap_suscrito,v_cap_integrado,v_can_acc_portador,v_can_acc_nominativa);
           if nvl(rp_scta.cod_moneda,0)<>nvl(v_cod_moneda,0) then
             v_modificado:='S';
           elsif nvl(rp_scta.cap_suscrito,0)<>nvl(v_cap_suscrito,0) then
             v_modificado:='S';
           elsif nvl(rp_scta.cap_integrado,0) <> nvl(v_cap_integrado,0) then
             v_modificado:='S';
           elsif nvl(rp_scta.can_acc_portador,0)<>nvl(v_can_acc_portador,0) then
             v_modificado:='S';
           elsif nvl(rp_scta.can_acc_nominativa,0)<>nvl(v_can_acc_nominativa,0) then
             v_modificado:='S';
           end if;          
         else
         rp_scta.estado:='A';
         end if;
         rp_scta.cod_persona:=v_cliente;
         if ((v_ind_acc='N' and rp_scta.can_acc_nominativa is not null and rp_scta.cod_moneda is not null and rp_scta.cap_suscrito is not null and rp_scta.cap_integrado is not null )
            or (v_ind_acc='S' and rp_scta.can_acc_portador is not null and rp_scta.cod_moneda is not null and rp_scta.cap_suscrito is not null and rp_scta.cap_integrado is not null  
            )) then
           if (rp_scta.estado='M' and v_modificado ='S') or (rp_scta.estado='A') then
             lp_ins_sociedades(rp_scta);
           end if;
         end if;
        end if ;
    END LOOP;
 END LOOP;    
END;

PROCEDURE pr_inf_modificacion        
   IS  
      ---cursor para modificaciones de sociedades 
         CURSOR mof_soc IS
            SELECT t.cod_persona
             FROM ba_acc_portador t
             WHERE nvl(t.informado,'N')='S'
             and (nvl(t.cod_moneda,'')<>nvl(t.cod_mon_ant,'') 
             or nvl(t.cap_suscrito,0)<>nvl(t.cap_sus_ant,0)
             or nvl(t.cap_integrado,0)<>nvl(t.cap_int_ant,0)
             or nvl(t.can_acc_portador,0)<>nvl(t.can_acc_por_ant,0)
             or nvl(t.can_acc_nominativa,0)<>nvl(t.can_acc_nom_ant,0))
             and not exists (select 1 from sb_bcp_acciones p where p.cod_persona=t.cod_persona and p.estado in('A','M')
                           and p.fecha=v_fec_anterior);
BEGIN 
      FOR mof IN mof_soc  LOOP        
         lp_obt_dat_cliente(mof.cod_persona,rp_scta.tip_documento,rp_scta.nro_documento, rp_scta.cod_moneda,rp_scta.cap_suscrito,rp_scta.cap_integrado,rp_scta.can_acc_portador,rp_scta.can_acc_nominativa,v_ind_acc);      
         rp_scta.fecha:= v_fec_anterior;
         rp_scta.nro_formulario:='015';
         rp_scta.estado:='M';
         rp_scta.cod_persona:=mof.cod_persona;
         if ((v_ind_acc='N' and rp_scta.can_acc_nominativa is not null and rp_scta.cod_moneda is not null and rp_scta.cap_suscrito is not null and rp_scta.cap_integrado is not null )
            or (v_ind_acc='S' and rp_scta.can_acc_portador is not null and rp_scta.cod_moneda is not null and rp_scta.cap_suscrito is not null and rp_scta.cap_integrado is not null  
            )) then           
           lp_ins_sociedades(rp_scta);
         end if;       
    END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20002,rp_scta.nro_documento||' '||SQLERRM);
   END; 
   
PROCEDURE pr_inf_bajas      
   IS  
  v_informar varchar2(1):='N';   
        CURSOR per_eli IS
           SELECT distinct t.cod_persona
             FROM sb_bcp_acc_eliminadas t
             where not exists (select 1 from ba_acc_portador p where p.cod_persona=t.cod_persona)
             and t.fecha=v_fec_anterior;   
        
BEGIN    
     FOR baj IN per_eli  LOOP
        v_informar:=lf_ver_estado(baj.cod_persona);
        if v_informar <>'B' then
         lp_obt_dat_sociedades(baj.cod_persona,rp_scta.tip_documento,rp_scta.nro_documento, rp_scta.cod_moneda,rp_scta.cap_suscrito,rp_scta.cap_integrado,rp_scta.can_acc_portador,rp_scta.can_acc_nominativa);      
         rp_scta.fecha:= v_fec_anterior;
         rp_scta.nro_formulario:='015';
         rp_scta.estado:='B';
         rp_scta.cod_persona:=baj.cod_persona;
         if rp_scta.nro_documento is not null then--- solo si se informó alguna vez como alta
           lp_ins_sociedades(rp_scta);        
         end if;
        END IF;
    END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20002,rp_scta.nro_documento||' '||SQLERRM);
   END;    
PROCEDURE pr_act_cam_anteriores        
   IS     
        CURSOR act IS
           SELECT t.cod_persona
             FROM ba_acc_portador t;        
BEGIN    
     FOR i IN act  LOOP       
       ---actualizar campos ant (anteriores)
         update BA_ACC_PORTADOR g
          set g.cod_mon_ant=g.cod_moneda, 
          g.cap_sus_ant=g.cap_suscrito, 
          g.cap_int_ant=g.cap_integrado,
          g.can_acc_por_ant=g.can_acc_portador,
          g.can_acc_nom_ant=g.can_acc_nominativa
          where g.cod_persona=i.cod_persona;             
    END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20002,rp_scta.nro_documento||' '||SQLERRM);
   END; 
--Genera informe de Sociedades Circular 218
PROCEDURE pr_inf_sociedades
IS
  v_repository         VARCHAR2(100) :=  fug_obt_pardinamico('DIR_REP_ARC_TAS_SEM_DET');  
  v_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  v_port               VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  v_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  v_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');  
  v_operaciones        VARCHAR2(100) := 'ftp_dir';
  v_fecha              VARCHAR2(8);  
  v_file               UTL_FILE.FILE_TYPE;
  v_line               VARCHAR2(32767);
  v_linetit            VARCHAR2(2000);
  v_buffer             VARCHAR2(32767);
  v_name               VARCHAR2(128) := 'SOCIEDADES-'||fug_obt_cod_entidad; -- nombre del archivo
  v_lines              PLS_INTEGER := 0;
  v_eol                CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen             CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline            CONSTANT PLS_INTEGER := 32767;
  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type; 
  
CURSOR inf_sociedades IS
    select nro_formulario, 
          to_char(fecha,'yyyymmdd') fecha,
          tip_documento, 
          nro_documento, 
          cod_moneda, 
          cap_suscrito, 
          cap_integrado, 
          nvl(can_acc_portador,0) can_acc_portador, 
          nvl(can_acc_nominativa,0) can_acc_nominativa, 
          estado
    from sb_bcp_acciones
    where fecha=v_fec_anterior;

BEGIN  
-- Obtenemos la hora de la base de datos
v_fecha:= to_char(v_fec_anterior,'yyyymmdd');
-- verificar conexiones abiertas anteriormente
IF UTL_FILE.IS_OPEN(v_file) THEN
   UTL_FILE.FCLOSE(v_file);
   UTL_FILE.FCLOSE_ALL;
END IF;

-- Abrir archivo
v_file := UTL_FILE.FOPEN(v_repository,v_name||'.csv','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FORMULARIO'||';'||'FECHA_DE_REGISTRO'||';'||'TIP_DOCUMENTO'||';'||'NRO_DOCUMENTO'||';'||'COD_MONEDA'||';'||
             'MTO_CAP_SUSCRITO'||';'||'MTO_CAP_INTEGRADO'||';'||'CAN_ACC_PORTADOR'||';'||'CAN_ACC_NOMINATIVA'||';'||'ESTADO';

utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN inf_sociedades LOOP
    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.nro_formulario)||';'||to_char(rec.fecha)||';'||to_char(rec.tip_documento)||';'||to_char(rec.nro_documento)||';'||
            to_char(rec.cod_moneda)||';'||to_number(rec.cap_suscrito)||';'||to_number(rec.cap_integrado)||';'||
            to_char(rec.can_acc_portador)||';'||to_char(rec.can_acc_nominativa)||';'||
            to_char(rec.estado);
    IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
      v_buffer := v_buffer || v_eol || v_line;
    ELSE
      IF v_buffer IS NOT NULL THEN
        --Escribes la linea en el fichero
        UTL_FILE.PUT_LINE(v_file, v_buffer);
      END IF;
      v_buffer := v_line;
    END IF;
    v_lines := v_lines + 1;
  EXIT WHEN inf_sociedades%NOTFOUND;
END LOOP;
 --Escribes la linea en el fichero
 UTL_FILE.PUT_LINE(v_file, v_buffer);
 --Cerrar el handler al fichero
 UTL_FILE.FCLOSE(v_file);
 IF UTL_FILE.IS_OPEN(v_file) THEN
    UTL_FILE.FCLOSE(v_file);
	UTL_FILE.FCLOSE_ALL;
 END IF;
 
  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(v_ip, v_port, v_user,
                                          v_pass, v_repository,
                                          v_name||'.csv', v_operaciones||v_name||'-'||v_fecha||'.csv');
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

 IF v_respuesta <> 'OK' THEN  --ARCHIVO ENVIADO POR FTP  
    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'-'||v_fecha||'.csv', v_respuesta, v_hini_ftp, v_hfin_ftp);  
 END IF;
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
	UTL_FILE.FCLOSE_ALL;
    RAISE_APPLICATION_ERROR(-20061,'Operacion invalida '||sqlerrm);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
	UTL_FILE.FCLOSE_ALL;
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido '||sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
	UTL_FILE.FCLOSE_ALL;
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
	UTL_FILE.FCLOSE_ALL;
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido '||sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error '||sqlerrm);
   WHEN OTHERS THEN
   UTL_FILE.FCLOSE(v_file);
   UTL_FILE.FCLOSE_ALL;
   RAISE_APPLICATION_ERROR(-20066,'Internal Error '||sqlerrm);
END;  
---    
BEGIN
-- Inicio de Procesos --
 v_fec_anterior := pag_cal.fu_obt_fec_anterior(1); -- Hallamos la fecha del modulo 1 (general)
 v_informado :='N';  
 BEGIN
 select 'S' into v_informado from sb_bcp_acciones g where g.fecha=v_fec_anterior and rownum=1;
    EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_informado:='N';         
      END;   
 if v_informado= 'N' then
      v_lugar:= 'pr_inf_altas';
       pr_inf_altas; ---genera las altas de sociedades
       v_lugar:= 'pr_inf_modificacion';
       pr_inf_modificacion;--genera las modificaciones de sociedades
       v_lugar:= 'pr_inf_bajas';
       pr_inf_bajas; ---genera las bajas de sociedades
       v_lugar:= 'pr_act_cam_anteriores';
       pr_act_cam_anteriores;--actualiza los campos ant (anteriores)
       v_lugar:= 'pr_inf_sociedades';
       pr_inf_sociedades;--- genera el informe en csv y envia mail de aviso al usuario final
  end if;  
  exception
        when others then
          UTL_FILE.FCLOSE_ALL;
          RAISE_APPLICATION_ERROR(-20002,'Error general. El informe ya fue ejecutado'||' lugar: '||v_lugar||' '||SQLERRM);  
END;
/
