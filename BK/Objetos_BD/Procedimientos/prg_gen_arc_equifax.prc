create or replace procedure it.PRG_GEN_ARC_EQUIFAX (P_TIP_ARCHIVO IN VARCHAR2,
                                                 P_TIP_PROCESO IN VARCHAR2,
                                                 P_FTP IN VARCHAR2 Default 'S') is

  v_repository         VARCHAR2(100) := fug_obt_pardinamico('DIR_AUT_BANCARD');
  v_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  v_port               VARCHAR2(100) := '21';
  v_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  v_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_directorio         VARCHAR2(100) := fug_obt_pardinamico('DIR_GEN_ARC_EQUIFAX');
  v_file               UTL_FILE.FILE_TYPE;
  v_line               VARCHAR2(32767);
  v_linetit            VARCHAR2(2000);
  v_buffer             VARCHAR2(32767);
  v_cod_ente           varchar2(15)   := fug_obt_pardinamico('COD_ENT_BAS_POSITIVA');
  v_ext_archivo        varchar2(5)   := 'csv';
  v_maxline            CONSTANT PLS_INTEGER := 32767;
  v_eol                CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen             CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_lines              PLS_INTEGER := 0;
  v_fec_actual         date := pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_can_reg_1p         number := 0;
  v_can_reg_3t         number := 0;
  v_respuesta          VARCHAR2(4000);
  v_tip_archivo        varchar2(1);
  --v_tip_accion         varchar2(1);
  v_tip_operacion      varchar2(1);
  v_error              varchar2(500);
  v_generar            varchar2(1) := 'N';
  v_contador           number := 0;
  v_env_ws             varchar2(1)   := fug_obt_pardinamico('ENV_SER_BAS_POSITIVA');
  v_nom_archivo        varchar2(4000);
  v_pri_vez         VARCHAR2(1) := nvl(fug_obt_pardinamico('INF_PRI_ARC_EQUIFAX'),'N');
  v_inf_PJ       VARCHAR2(1) := nvl(fug_obt_pardinamico('INF_PJ_ARC_EQUIFAX'),'N');
  v_tip_accion      varchar2(1);
  CURSOR PER_FISICAS IS
      Select a.tip_accion, a.cod_sucursal, a.tip_transaccion, a.id_operacion, a.tip_vinculacion, a.nro_cliente, a.can_dia_atraso,
             a.ope_cerrada, a.periodo, a.consentimiento, c.tip_prestamo, pas_cri.fu_obt_mon_iso(c.cod_moneda) cod_moneda, c.mto_capital,
             c.tot_cuotas, c.per_pago, c.fec_otorgado, null id_tarjeta, c.comp_mes, c.sal_total, c.refuerzos, c.can_cuo_pendientes,
             c.cuo_mes, c.sal_vencido, pas_cri.fu_obt_mon_iso(c.cod_moneda) cod_mon_detalle, a.fec_valor, a.tip_documento,
             a.cod_pai_documento, a.nro_documento, a.nacionalidad, a.pri_apellido, a.seg_apellido, a.ape_casada, a.pri_nombre, a.seg_nombre,
             a.fec_nacimiento, a.cod_sexo, a.est_civil, a.calle, a.nro_puerta, a.apartamento, a.piso, a.complemento, a.kilometro, a.manzana,
             a.lote, a.block, a.esquina1, a.esquina2, a.pension, a.tip_vivienda, a.id_ciudad, a.ciudad, a.barrio, a.departamento,
             a.cod_postal, a.telefono, a.emp_empleo, a.cargo, a.profesion, a.calle_laboral, a.nro_pue_laboral, a.apart_laboral, a.piso_laboral,
             a.comp_laboral, a.kilo_laboral, a.man_laboral, a.lote_laboral, a.blo_laboral, a.esq1_laboral, a.esq2_laboral, a.id_ciu_laboral,
             a.ciu_laboral, a.loc_laboral, a.dep_laboral, a.cod_pos_laboral, a.ing_empleo, a.tel_empleo, a.tip_doc_conyuge, a.pai_doc_conyuge,
             a.nro_doc_conyuge, a.nac_conyuge, a.pri_ape_conyuge, a.seg_ape_conyuge, a.ape_cas_conyuge, a.pri_nom_conyuge, a.seg_nom_conyuge,
             null dia_atr_cierre, null lim_cre_dis_cie, null tot_com_cierre, null sal_tot_cierre, null sal_cuo_cierre, null sal_ven_cierre, null lim_cre_cierre,
             c.est_deuda
      From ge_equ_per_fisicas a, ge_equ_prestamos c
      where a.fecha         = c.fecha
        and c.nro_secuencia = a.nro_secuencia(+)
        and a.tip_proceso   = P_TIP_PROCESO
        and a.tip_transaccion = '1P'
        and a.tip_accion    = nvl(V_TIP_ARCHIVO,A.TIP_ACCION)
        and v_tip_operacion = 'P'
      union all
      Select a.tip_accion, a.cod_sucursal, a.tip_transaccion, a.id_operacion, a.tip_vinculacion, a.nro_cliente, a.can_dia_atraso,
             a.ope_cerrada, a.periodo, a.consentimiento, d.tip_tarjeta, pas_cri.fu_obt_mon_iso(d.cod_moneda) cod_moneda, d.lim_cre_cabecera,
             d.lim_financiacion, d.lim_ret_efectivo, d.fec_emision, d.ind_tarjeta, d.mto_pag_minimo, d.lim_cre_detalle, d.tot_com_mes, d.sal_total,
             d.sal_cuotas, d.sal_vencido, null cod_mon_detalle, a.fec_valor, a.tip_documento,
             a.cod_pai_documento, a.nro_documento, a.nacionalidad, a.pri_apellido, a.seg_apellido, a.ape_casada, a.pri_nombre, a.seg_nombre,
             a.fec_nacimiento, a.cod_sexo, a.est_civil, a.calle, a.nro_puerta, a.apartamento, a.piso, a.complemento, a.kilometro, a.manzana,
             a.lote, a.block, a.esquina1, a.esquina2, a.pension, a.tip_vivienda, a.id_ciudad, a.ciudad, a.barrio, a.departamento,
             a.cod_postal, a.telefono, a.emp_empleo, a.cargo, a.profesion, a.calle_laboral, a.nro_pue_laboral, a.apart_laboral, a.piso_laboral,
             a.comp_laboral, a.kilo_laboral, a.man_laboral, a.lote_laboral, a.blo_laboral, a.esq1_laboral, a.esq2_laboral, a.id_ciu_laboral,
             a.ciu_laboral, a.loc_laboral, a.dep_laboral, a.cod_pos_laboral, a.ing_empleo, a.tel_empleo, a.tip_doc_conyuge, a.pai_doc_conyuge,
             a.nro_doc_conyuge, a.nac_conyuge, a.pri_ape_conyuge, a.seg_ape_conyuge, a.ape_cas_conyuge, a.pri_nom_conyuge, a.seg_nom_conyuge ,
             d.dia_atr_cierre, d.lim_cre_dis_cie, d.tot_com_cierre, d.sal_tot_cierre, d.sal_cuo_cierre, d.sal_ven_cierre, d.lim_cre_cierre,
             null est_deuda
      From ge_equ_per_fisicas a, ge_equ_tarjetas d
      where a.fecha         = d.fecha
        and a.nro_secuencia = d.nro_secuencia(+)
        and a.tip_proceso   = P_TIP_PROCESO
        and a.tip_transaccion = '3T'
        and a.tip_accion    = nvl(V_TIP_ARCHIVO,A.TIP_ACCION)
        and v_tip_operacion = 'T';

     CURSOR PER_JURIDICAS IS
      Select a.tip_accion, a.cod_sucursal, a.tip_transaccion, a.id_operacion, a.tip_vinculacion, a.nro_cliente, a.can_dia_atraso, a.ope_cerrada,
             a.periodo, a.consentimiento, c.tip_prestamo tip_prestamo, pas_cri.fu_obt_mon_iso(c.cod_moneda) cod_moneda, c.mto_capital,
             c.tot_cuotas, c.per_pago, c.fec_otorgado, null id_tarjeta, c.comp_mes, c.sal_total, c.refuerzos, c.can_cuo_pendientes,
             c.cuo_mes, c.sal_vencido, pas_cri.fu_obt_mon_iso(c.cod_moneda) cod_mon_detalle, a.fec_valor, a.tip_documento,
             a.cod_pai_documento, a.nro_documento, a.raz_social, a.nom_empresa, a.act_comercial, a.ini_actividades, a.calle, a.nro_puerta,
             a.apartamento, a.piso, a.complemento, a.kilometro, a.manzana, a.lote, a.block, a.esquina1, a.esquina2, a.tip_vivienda, a.id_ciudad,
             a.ciudad, a.barrio, a.departamento, a.cod_postal, a.telefono,
             null dia_atr_cierre, null lim_cre_dis_cie, null tot_com_cierre, null sal_tot_cierre, null sal_cuo_cierre, null sal_ven_cierre, null lim_cre_cierre,
             c.est_deuda
      From ge_equ_per_juridicas a, ge_equ_prestamos c
      where a.fecha         = c.fecha
        and c.nro_secuencia = a.nro_secuencia(+)
        and a.tip_proceso   = P_TIP_PROCESO
        and a.tip_transaccion = '1P'
        and a.tip_accion    = nvl(V_TIP_ARCHIVO,a.tip_accion)
        and v_tip_operacion = 'P'
      union all
      Select a.tip_accion, a.cod_sucursal, a.tip_transaccion, a.id_operacion, a.tip_vinculacion, a.nro_cliente, a.can_dia_atraso, a.ope_cerrada,
             a.periodo, a.consentimiento, to_char(d.tip_tarjeta), pas_cri.fu_obt_mon_iso(d.cod_moneda) cod_moneda, d.lim_cre_cabecera,
             d.lim_financiacion, d.lim_ret_efectivo, d.fec_emision, d.ind_tarjeta, d.mto_pag_minimo, d.lim_cre_detalle, d.tot_com_mes, d.sal_total,
             d.sal_cuotas, d.sal_vencido, null cod_mon_detalle, a.fec_valor, a.tip_documento,
             a.cod_pai_documento, a.nro_documento, a.raz_social, a.nom_empresa, a.act_comercial, a.ini_actividades, a.calle, a.nro_puerta,
             a.apartamento, a.piso, a.complemento, a.kilometro, a.manzana, a.lote, a.block, a.esquina1, a.esquina2, a.tip_vivienda, a.id_ciudad,
             a.ciudad, a.barrio, a.departamento, a.cod_postal, a.telefono,
             d.dia_atr_cierre, d.lim_cre_dis_cie, d.tot_com_cierre, d.sal_tot_cierre, d.sal_cuo_cierre, d.sal_ven_cierre, d.lim_cre_cierre,
             null est_deuda
      From ge_equ_per_juridicas a, ge_equ_tarjetas d
      where a.fecha         = d.fecha
        and a.nro_secuencia = d.nro_secuencia(+)
        and a.tip_proceso   = P_TIP_PROCESO
        and a.tip_transaccion = '3T'
        and a.tip_accion    = nvl(V_TIP_ARCHIVO,A.TIP_ACCION)
        and v_tip_operacion = 'T';


     PROCEDURE P_INS_WS (P_FECHA          IN GE_EQU_DATOS.FECHA%TYPE        ,
                         P_NUM_CLIENTE    IN GE_EQU_DATOS.NUM_CLIENTE%TYPE  ,
                         P_TIP_PERSONA    IN GE_EQU_DATOS.TIP_PERSONA%TYPE  ,
                         P_NOM_ARCHIVO    IN GE_EQU_DATOS.NOM_ARCHIVO%TYPE  ,
                         P_TIP_OPERACION  IN GE_EQU_DATOS.TIP_OPERACION%TYPE,
                         P_TIP_ARCHIVO    IN GE_EQU_DATOS.TIP_ARCHIVO%TYPE  ) IS
            l_bfile             BFILE;
            l_blob              CLOB;
            v_tip_procesamiento varchar2(1);
          BEGIN
            /*if nvl(pae_cnf.G_PROGRAMA, 'X') = ('GEQUIFAX') Then
               v_tip_procesamiento := 'M';
            Else
               v_tip_procesamiento := 'A';
            End If;
            INSERT INTO GE_EQU_DATOS(FECHA               ,
                                     NUM_CLIENTE         ,
                                     DATOS               ,
                                     TIP_PERSONA         ,
                                     NOM_ARCHIVO         ,
                                     TIP_OPERACION       ,
                                     TIP_ARCHIVO         ,
                                     TIP_PROCESO         ,
                                     ESTADO              )
                            VALUES  (P_FECHA             ,
                                     P_NUM_CLIENTE       ,
                                     EMPTY_CLOB()        ,
                                     P_TIP_PERSONA       ,
                                     P_NOM_ARCHIVO||'.'||P_TIP_ARCHIVO,
                                     P_TIP_OPERACION     ,
                                     P_TIP_ARCHIVO       ,
                                     V_TIP_PROCESAMIENTO ,
                                     'P'                 )
            RETURNING DATOS INTO l_blob;

            l_bfile := BFILENAME(V_REPOSITORY, P_NOM_ARCHIVO||'.'||V_EXT_ARCHIVO);
            DBMS_LOB.fileopen(l_bfile, Dbms_Lob.File_Readonly);
            DBMS_LOB.loadfromfile(l_blob,
                                  l_bfile,
                                  DBMS_LOB.getlength(l_bfile));
            DBMS_LOB.fileclose(l_bfile);

            UPDATE GE_EQU_DATOS A
               SET A.DATOS         = FUG_UPD_CARACTERES(A.DATOS,chr(10), chr(63))
             WHERE A.FECHA         = P_FECHA
               AND A.TIP_PERSONA   = P_TIP_PERSONA
               AND A.NOM_ARCHIVO   = P_NOM_ARCHIVO
               AND A.TIP_OPERACION = P_TIP_OPERACION;
               */null;
          EXCEPTION
              WHEN OTHERS THEN
                   raise_application_error (-20000, 'Error Generando Datos Blob: '||P_NOM_ARCHIVO||' - '||sqlerrm);
          END;
     FUNCTION FU_VER_EXISTE (P_FECHA         IN DATE    ,
                             P_TIP_PERSONA   IN VARCHAR2,
                             P_NOM_ARCHIVO   IN VARCHAR2,
                             P_TIP_OPERACION GE_EQU_DATOS.TIP_OPERACION%TYPE) RETURN BOOLEAN IS
          v_existe        VARCHAR2(1);
          BEGIN
               Select 'S'
                 into v_existe
                 from ge_equ_datos a
                where a.fecha         = P_FECHA
                  and a.tip_persona   = P_TIP_PERSONA
                  and a.nom_archivo   = P_NOM_ARCHIVO
                  and a.tip_operacion = P_TIP_OPERACION;
                RETURN TRUE;
          EXCEPTION
              WHEN too_many_rows THEN
                   RETURN TRUE;
              WHEN no_data_found THEN
                 RETURN FALSE;
              WHEN OTHERS THEN
                 RETURN FALSE;
          END;

      PROCEDURE PR_COM_ARCHIVO(P_NOM_ARCHIVO   IN VARCHAR2,
                               P_TIP_ARCHIVO   IN VARCHAR2) IS
        v_archivo clob;
        v_arcblob blob;
        g_zipped_blob blob;
      BEGIN
        BEGIN
          SELECT datos
            INTO v_archivo
            FROM ge_equ_datos q
           WHERE q.nom_archivo = P_NOM_ARCHIVO||'.'||P_TIP_ARCHIVO
             AND q.tip_proceso = P_TIP_PROCESO;
        END;
        v_arcblob := fug_con_lob(v_archivo);
        pag_zip.add1file( g_zipped_blob, p_nom_archivo||'.'||v_ext_archivo, v_arcblob);
        pag_zip.finish_zip( g_zipped_blob );
        pag_zip.save_zip( g_zipped_blob, v_repository, p_nom_archivo||'.'||p_tip_archivo );
     END;
     FUNCTION FU_OBT_TIP_ACCION (P_NRO_OPERACION   IN VARCHAR2 ,
                                 P_PERIODO         IN VARCHAR2 ) RETURN VARCHAR2 IS
          v_tip_accion        VARCHAR2(1);
          BEGIN
               Select 'M'
                 into v_tip_accion
                 from ge_equ_per_fisicas_his a
                where a.id_operacion  = P_NRO_OPERACION
                  and a.periodo       = P_PERIODO
               union
               Select 'M'
                 from ge_equ_per_juridicas_his j
                where j.id_operacion = P_NRO_OPERACION
                  and j.periodo      = P_PERIODO;
                RETURN v_tip_accion;
          EXCEPTION
              WHEN too_many_rows THEN
                   RETURN 'M';
              WHEN no_data_found THEN
                 RETURN 'I';
              WHEN OTHERS THEN
                 RETURN 'I';
          END;
BEGIN
     Begin --> Traslado al Hit rico
         /*insert into GE_EQU_DATOS_HIS(FECHA,HORA,NUM_CLIENTE,DATOS,TIP_PERSONA,NOM_ARCHIVO,TIP_OPERACION,COMENTARIO,TIP_ARCHIVO,DAT_BASE64,TIP_PROCESO,ESTADO,ERROR)
         Select FECHA,to_char(sysdate,'HH24:MM:SS') HORA,NUM_CLIENTE,DATOS,TIP_PERSONA,NOM_ARCHIVO,TIP_OPERACION,COMENTARIO,TIP_ARCHIVO,DAT_BASE64,TIP_PROCESO,ESTADO,ERROR
           from GE_EQU_DATOS a
          where substr(a.nom_archivo,1,instr(a.nom_archivo,'.zip')-1) =
                decode(P_TIP_ARCHIVO,'TODOS',substr(a.nom_archivo,1,instr(a.nom_archivo,'.zip')-1),P_TIP_ARCHIVO)
            and a.tip_proceso = P_TIP_PROCESO
          ;*/null;
     Exception
            When Others Then
                 raise_application_error(-20000,'Error Trasladando al Hist rico '||sqlerrm);
     End;
     Begin -- Elimino el registro ya existente trasladado al hist rico.-
          /*delete ge_equ_datos a
           where substr(a.nom_archivo,1,instr(a.nom_archivo,'.zip')-1) =
                 decode(P_TIP_ARCHIVO,'TODOS',substr(a.nom_archivo,1,instr(a.nom_archivo,'.zip')-1),P_TIP_ARCHIVO)
            and a.tip_proceso = P_TIP_PROCESO;*/null;
     Exception
          When Others Then
                 raise_application_error(-20000,'Error borrando datos al Trasladar al Hist rico '||sqlerrm);
     End;
     --Para Personas Fisicas *****************************************************
       If P_TIP_ARCHIVO = 'ALT_PER_FISICAS' or P_TIP_ARCHIVO = 'TODOS' then
           v_line       := null;
           --Para altas primera vez y despues siempre va 'I'
           V_TIP_ARCHIVO := 'I';
           v_linetit    := null;
           IF UTL_FILE.IS_OPEN(V_FILE) THEN
              UTL_FILE.FCLOSE(V_FILE);
           END IF;
           FOR loop_operacion IN 1..2 LOOP
              -- Determinar el valor de v_nom_archivo en cada iteraci n
              IF loop_operacion = 1 THEN
                  v_tip_operacion := 'T';
                  v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_PERSONAS_ALTA_TARJETA_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
              ELSE
                  -- Para la segunda iteraci n, cambiar el valor de v_nom_archivo
                  v_tip_operacion := 'P';
                  v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_PERSONAS_ALTA_PRESTAMO_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
              END IF;
             --v_nom_archivo  := LPAD(v_cod_ente, 6, '0')||'_PERSONAS_ALTA_'||to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'MMYYYY');
             v_file := UTL_FILE.FOPEN(v_repository,v_nom_archivo||'.'||v_ext_archivo,'W',32767);

             -- Cabecera
             v_line :=   v_cod_ente        ||';'||
                         '01'         ||';'||
                         'INICIO ARCHIVO'  ||';'||
                         'ALTAS PERSONAS'  ||';'||
                         to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMMDD')||';'||
                         to_char(sysdate,'HHMMSS')||';'||
                         to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMM')||';'||
                         ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                         ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                         ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                         ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                         ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                         ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                         ';'||';'||';'||';'||';'||';'||';'||';';
             utl_file.put_line(v_file,v_line);
             v_error := 'PER_FISICAS';
             v_buffer     := null;
             FOR i IN PER_FISICAS LOOP
                 v_generar := 'S';
                 If i.tip_transaccion = '1P' Then
                      v_can_reg_1p :=  v_can_reg_1p + 1;
                 Elsif i.tip_transaccion = '3T' Then
                      v_can_reg_3t :=  v_can_reg_3t + 1;
                 End If;
                 v_contador := v_contador + 1;
                 
                 if nvl(v_pri_vez,'N') ='S'  then
                   v_tip_accion:='I';
                 else
                   v_tip_accion:=i.tip_accion;
                 end if;
                 v_line := v_tip_accion            ||';'||
                           i.cod_sucursal          ||';'||
                           i.tip_transaccion       ||';'||
                           i.id_operacion          ||';'||
                           i.tip_vinculacion       ||';'||
                           i.nro_cliente           ||';'||
                           i.periodo               ||';'||
                           i.tip_prestamo          ||';'||
                           i.cod_moneda            ||';'||
                           i.mto_capital           ||';'||
                           i.tot_cuotas            ||';'||
                           i.per_pago              ||';'||
                           i.fec_otorgado          ||';'||
                           i.id_tarjeta            ||';'||
                           i.fec_valor             ||';'||
                           i.tip_documento         ||';'||
                           i.cod_pai_documento     ||';'||
                           i.nro_documento         ||';'||
                           i.nacionalidad          ||';'||
                           i.pri_apellido          ||';'||
                           i.seg_apellido          ||';'||
                           i.ape_casada            ||';'||
                           i.pri_nombre            ||';'||
                           i.seg_nombre            ||';'||
                           i.fec_nacimiento        ||';'||
                           i.cod_sexo              ||';'||
                           i.est_civil             ||';'||
                           i.calle                 ||';'||
                           i.nro_puerta            ||';'||
                           i.apartamento           ||';'||
                           i.piso                  ||';'||
                           i.complemento           ||';'||
                           i.kilometro             ||';'||
                           i.manzana               ||';'||
                           i.lote                  ||';'||
                           i.block                 ||';'||
                           i.esquina1              ||';'||
                           i.esquina2              ||';'||
                           i.pension               ||';'||
                           i.tip_vivienda          ||';'||
                           i.id_ciudad             ||';'||
                           i.ciudad                ||';'||
                           i.barrio                ||';'||
                           i.departamento          ||';'||
                           i.cod_postal            ||';'||
                           i.telefono              ||';'||
                           i.emp_empleo            ||';'||
                           i.cargo                 ||';'||
                           i.profesion             ||';'||
                           i.calle_laboral         ||';'||
                           i.nro_pue_laboral       ||';'||
                           i.apart_laboral         ||';'||
                           i.piso_laboral          ||';'||
                           i.comp_laboral          ||';'||
                           i.kilo_laboral          ||';'||
                           i.man_laboral           ||';'||
                           i.lote_laboral          ||';'||
                           i.blo_laboral           ||';'||
                           i.esq1_laboral          ||';'||
                           i.esq2_laboral          ||';'||
                           i.id_ciu_laboral        ||';'||
                           i.ciu_laboral           ||';'||
                           i.loc_laboral           ||';'||
                           i.dep_laboral           ||';'||
                           i.cod_pos_laboral       ||';'||
                           i.ing_empleo            ||';'||
                           i.tel_empleo            ||';'||
                           i.tip_doc_conyuge       ||';'||
                           i.pai_doc_conyuge       ||';'||
                           i.nro_doc_conyuge       ||';'||
                           i.nac_conyuge           ||';'||
                           i.pri_ape_conyuge       ||';'||
                           i.seg_ape_conyuge       ||';'||
                           i.ape_cas_conyuge       ||';'||
                           i.pri_nom_conyuge       ||';'||
                           i.seg_nom_conyuge       ;
                 IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
                    v_buffer := v_buffer || v_eol || v_line;
                 ELSE
                    IF v_buffer IS NOT NULL THEN
                        UTL_FILE.PUT_LINE(v_file, v_buffer);
                    END IF;
                    v_buffer := v_line;
                 END IF;
                 EXIT WHEN PER_FISICAS%NOTFOUND;
             END LOOP;
             UTL_FILE.PUT_LINE(v_file, v_buffer);
               IF loop_operacion = 1 THEN
                 V_CAN_REG_1P:=0;
               else
                 V_CAN_REG_3T:=0;
               end if;
             v_line :=  'FIN ARCHIVO'    ||';'||
                        V_CAN_REG_1P     ||';'||
                        V_CAN_REG_3T ||';'||
                        '0'              ||';'||
                        '0'              ||';'||
                        '0'              ||';'||
                        ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                        ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                        ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                        ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                        ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                        ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                        ';'||';'||';'||';'||';'||';'||';'||';'||';';
              UTL_FILE.PUT_LINE(v_file, v_line);
              UTL_FILE.FCLOSE(v_file);
              If v_generar = 'S' Then
                  P_INS_WS(v_fec_actual,
                           v_cod_ente,
                           'F',
                           v_nom_archivo,
                           14, --Altas de Base Positiva
                           'zip');
                  IF P_TIP_PROCESO = 'A' THEN
                   /*v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                                           v_port,
                                                           v_user,
                                                           v_pass,
                                                           v_repository,
                                                           v_nom_archivo||'.'||v_ext_archivo,
                                                           v_directorio||v_nom_archivo||'.'||v_ext_archivo);
                  */null;
                  ELSE
                    pr_com_archivo( v_nom_archivo, 'zip');
                  END IF;
              Else
                UTL_FILE.fremove(v_repository,v_nom_archivo||'.'||v_ext_archivo);
              End If;
              v_lines := v_lines + 1;
           END LOOP;
         End IF;
       --Para actualizac. de personas fisicas
        If P_TIP_ARCHIVO = 'ACT_PER_FISICAS' or P_TIP_ARCHIVO = 'TODOS' Then
           v_line       := null;
           --Primera Vez se informa todo como 'I'
           IF nvl(v_pri_vez,'N') ='S'  then
              V_TIP_ARCHIVO := 'I';
           ELSE
               V_TIP_ARCHIVO := 'M';
           END IF;
           v_generar    := 'N';
           v_linetit    := null;
           v_can_reg_1p := 0;
           v_can_reg_3t := 0;
           v_buffer     := null;
           IF UTL_FILE.IS_OPEN(V_FILE) THEN
              UTL_FILE.FCLOSE(V_FILE);
           END IF;
           --v_nom_archivo  := LPAD(v_cod_ente, 6, '0')||'_PERSONAS_ACT_'||to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'MMYYYY');
           FOR loop_operacion IN 1..2 LOOP
              -- Determinar el valor de v_nom_archivo en cada iteraci n
              IF loop_operacion = 1 THEN
                  v_tip_operacion := 'T';
                  v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_PERSONAS_ACT_TARJETA_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
              ELSE
                  -- Para la segunda iteraci n, cambiar el valor de v_nom_archivo
                  v_tip_operacion := 'P';
                  v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_PERSONAS_ACT_PRESTAMO_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
              END IF;
           v_file := UTL_FILE.FOPEN(v_repository,v_nom_archivo||'.'||v_ext_archivo,'W',32767);
           -- Cabecera
           v_linetit := v_cod_ente                 ||';'||
                       CASE
                        WHEN v_tip_operacion = 'T' THEN '02'            ||';'
                        ELSE                            '01'            ||';'
                       END  ||
                       'INICIO ARCHIVO'            ||';'||
                       'ACTUALIZACIONES PERSONAS'  ||';'||
                       to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMMDD')||';'||
                       to_char(sysdate,'HHMMSS')||';'||
                       to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMM')||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                       ';'||';';
           utl_file.put_line(v_file,v_linetit);
            v_error := 'PER_FISICAS_01';
           v_buffer     := null;
           FOR i IN PER_FISICAS LOOP
               v_generar    := 'S';
               If i.tip_transaccion = '1P' Then
                    v_can_reg_1p :=  v_can_reg_1p + 1;
               Elsif i.tip_transaccion = '3T' Then
                    v_can_reg_3t :=  v_can_reg_3t + 1;
               End If;
               if nvl(v_pri_vez,'N') ='S'  then
                   v_tip_accion:='I';
                 else
                   v_tip_accion:=i.tip_accion;
                 end if;
               --v_tip_accion := fu_obt_tip_accion(i.id_operacion, i.periodo);
               v_line := v_tip_accion            ||';'||
                         i.cod_sucursal          ||';'||
                         i.tip_transaccion       ||';'||
                         i.id_operacion          ||';'||
                         i.tip_vinculacion       ||';'||
                         i.nro_cliente           ||';'||
                         i.can_dia_atraso        ||';'||
                         i.ope_cerrada           ||';'||
                         i.periodo               ||';'||
                         i.consentimiento        ||';'||
                         i.comp_mes              ||';'||
                         i.sal_total             ||';'||
                         i.refuerzos             ||';'||
                         i.can_cuo_pendientes    ||';'||
                         i.cuo_mes               ||';'||
                         i.sal_vencido           ||';'||
                         i.cod_mon_detalle       ||';'||
                         i.est_deuda             ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         null                    ||';'||
                         CASE
                          WHEN v_tip_operacion = 'T' THEN i.mto_capital||';'
                          ELSE null
                         END                     || -- linea 19 de detalle de tarjetas - limite de credito/compra
                         i.fec_valor             ||';'||
                         i.tip_documento         ||';'||
                         i.cod_pai_documento     ||';'||
                         i.nro_documento         ||';'||
                         i.nacionalidad          ||';'||
                         i.pri_apellido          ||';'||
                         i.seg_apellido          ||';'||
                         i.ape_casada            ||';'||
                         i.pri_nombre            ||';'||
                         i.seg_nombre            ||';'||
                         i.fec_nacimiento        ||';'||
                         i.cod_sexo              ||';'||
                         i.est_civil             ||';'||
                         i.calle                 ||';'||
                         i.nro_puerta            ||';'||
                         i.apartamento           ||';'||
                         i.piso                  ||';'||
                         i.complemento           ||';'||
                         i.kilometro             ||';'||
                         i.manzana               ||';'||
                         i.lote                  ||';'||
                         i.block                 ||';'||
                         i.esquina1              ||';'||
                         i.esquina2              ||';'||
                         i.pension               ||';'||
                         i.tip_vivienda          ||';'||
                         i.id_ciudad             ||';'||
                         i.ciudad                ||';'||
                         i.barrio                ||';'||
                         i.departamento          ||';'||
                         i.cod_postal            ||';'||
                         i.telefono              ||';'||
                         i.emp_empleo            ||';'||
                         i.cargo                 ||';'||
                         i.profesion             ||';'||
                         i.calle_laboral         ||';'||
                         i.nro_pue_laboral       ||';'||
                         i.apart_laboral         ||';'||
                         i.piso_laboral          ||';'||
                         i.comp_laboral          ||';'||
                         i.kilo_laboral          ||';'||
                         i.man_laboral           ||';'||
                         i.lote_laboral          ||';'||
                         i.blo_laboral           ||';'||
                         i.esq1_laboral          ||';'||
                         i.esq2_laboral          ||';'||
                         i.id_ciu_laboral        ||';'||
                         i.ciu_laboral           ||';'||
                         i.loc_laboral           ||';'||
                         i.dep_laboral           ||';'||
                         i.cod_pos_laboral       ||';'||
                         i.ing_empleo            ||';'||
                         i.tel_empleo            ||';'||
                         i.tip_doc_conyuge       ||';'||
                         i.pai_doc_conyuge       ||';'||
                         i.nro_doc_conyuge       ||';'||
                         i.nac_conyuge           ||';'||
                         i.pri_ape_conyuge       ||';'||
                         i.seg_ape_conyuge       ||';'||
                         i.ape_cas_conyuge       ||';'||
                         i.pri_nom_conyuge       ||';'||
                         i.seg_nom_conyuge       ||
                         CASE -- Datos al cierre, solo para tarjetas
                          WHEN v_tip_operacion = 'T' THEN
                                                 ';'||
                            i.dia_atr_cierre     ||';'||
                            i.lim_cre_dis_cie    ||';'||
                            i.tot_com_cierre     ||';'||
                            i.sal_tot_cierre     ||';'||
                            i.sal_cuo_cierre     ||';'||
                            i.sal_ven_cierre     ||';'||
                            i.lim_cre_cierre
                          ELSE null
                         END ;
               IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
                  v_buffer := v_buffer || v_eol || v_line;
               ELSE
                  IF v_buffer IS NOT NULL THEN
                      UTL_FILE.PUT_LINE(v_file, v_buffer);
                   END IF;
                  v_buffer := v_line;
               END IF;
               EXIT WHEN PER_FISICAS%NOTFOUND;
           END LOOP;
           UTL_FILE.PUT_LINE(v_file, v_buffer);
               IF loop_operacion = 1 THEN
                 V_CAN_REG_1P:=0;
               else
                 V_CAN_REG_3T:=0;
               end if;
           v_line :=  'FIN ARCHIVO'    ||';'||
                      V_CAN_REG_1P     ||';'||
                      V_CAN_REG_3T     ||';'||
                      '0'              ||';'||
                      '0'              ||';'||
                      '0'              ||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                      ';'||';'||';';
            UTL_FILE.PUT_LINE(v_file, v_line);
              UTL_FILE.FCLOSE(v_file);
            If v_generar = 'S' Then
                P_INS_WS(v_fec_actual,
                         v_cod_ente,
                         'F',
                         v_nom_archivo,
                         15, --Actualizaciones de Base Positiva.
                         'zip');
                IF P_TIP_PROCESO = 'A' THEN
                  /*v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                                         v_port,
                                                         v_user,
                                                         v_pass,
                                                         v_repository,
                                                         v_nom_archivo||'.'||v_ext_archivo,
                                                         v_directorio||v_nom_archivo||'.'||v_ext_archivo);
                */null;
                ELSE
                  pr_com_archivo( v_nom_archivo, 'zip');
                END IF;
            Else
                UTL_FILE.fremove(v_repository,v_nom_archivo||'.'||v_ext_archivo);
            End If;
            v_lines := v_lines + 1;
         end loop;
     End If;
   --***************************************************************************************
   
   --*****Para Personas Juridicas **********************************************************

     If (P_TIP_ARCHIVO = 'ALT_PER_JURIDICAS' or P_TIP_ARCHIVO = 'TODOS')       
       AND nvl(v_inf_PJ,'N')='S' Then
         v_line       := null;
         --Siempre para el alta ya sea primera vez o no se informa 'I'
         V_TIP_ARCHIVO := 'I';
         v_generar    := 'N';
         v_linetit    := null;
         v_can_reg_1p := 0;
         v_can_reg_3t := 0;
         v_buffer     := null;
         IF UTL_FILE.IS_OPEN(V_FILE) THEN
            UTL_FILE.FCLOSE(V_FILE);
         END IF;
         --v_nom_archivo  := LPAD(v_cod_ente, 6, '0')||'_EMPRESAS_ALTA_'||to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'MMYYYY');
         FOR loop_operacion IN 1..2 LOOP
            -- Determinar el valor de v_nom_archivo en cada iteraci n
            IF loop_operacion = 1 THEN
                v_tip_operacion := 'T';
                v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_EMPRESAS_ALTA_TARJETA_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
            ELSE
                -- Para la segunda iteraci n, cambiar el valor de v_nom_archivo
                v_tip_operacion := 'P';
                v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_EMPRESAS_ALTA_PRESTAMO_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
            END IF;
         v_file       := UTL_FILE.FOPEN(v_repository,v_nom_archivo||'.'||v_ext_archivo,'W',32767);
         -- Cabecera
         v_linetit := v_cod_ente       ||';'||
                     '01'              ||';'||
                     'INICIO ARCHIVO'  ||';'||
                     'ALTAS EMPRESAS'  ||';'||
                     to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMMDD')||';'||
                     to_char(sysdate,'HHMMSS')||';'||
                     to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMM')||';'||
                     ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                     ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                     ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                     ';'||';';
         utl_file.put_line(v_file,v_linetit);
         v_error := 'PER_JURIDICAS';
         v_buffer     := null;
         FOR i IN PER_JURIDICAS LOOP
             v_generar := 'S';
             If i.tip_transaccion = '1P' Then
                  v_can_reg_1p :=  v_can_reg_1p + 1;
             Elsif i.tip_transaccion = '3T' Then
                  v_can_reg_3t :=  v_can_reg_3t + 1;
             End If;
             if nvl(v_pri_vez,'N') ='S'  then
                 v_tip_accion:='I';
               else
                 v_tip_accion:=i.tip_accion;
               end if;
             
             --v_tip_accion := fu_obt_tip_accion(i.id_operacion, i.periodo);
             v_line := v_tip_accion            ||';'||
                       i.cod_sucursal          ||';'||
                       i.tip_transaccion       ||';'||
                       i.id_operacion          ||';'||
                       i.tip_vinculacion       ||';'||
                       i.nro_cliente           ||';'||
                       i.periodo               ||';'||
                       i.tip_prestamo          ||';'||
                       i.cod_moneda            ||';'||
                       i.mto_capital           ||';'||
                       i.tot_cuotas            ||';'||
                       i.per_pago              ||';'||
                       i.fec_otorgado          ||';'||
                       CASE
                        WHEN v_tip_operacion = 'T' THEN i.id_tarjeta
                        ELSE '' -- dato solo p/ tarjeta
                       END                     ||';'||
                       i.fec_valor             ||';'||
                       i.tip_documento         ||';'||
                       i.cod_pai_documento     ||';'||
                       i.nro_documento         ||';'||
                       i.raz_social            ||';'||
                       i.nom_empresa           ||';'||
                       i.act_comercial         ||';'||
                       i.ini_actividades       ||';'||
                       i.calle                 ||';'||
                       i.nro_puerta            ||';'||
                       i.apartamento           ||';'||
                       i.piso                  ||';'||
                       i.complemento           ||';'||
                       i.kilometro             ||';'||
                       i.manzana               ||';'||
                       i.lote                  ||';'||
                       i.block                 ||';'||
                       i.esquina1              ||';'||
                       i.esquina2              ||';'||
                       i.tip_vivienda          ||';'||
                       i.id_ciudad             ||';'||
                       i.ciudad                ||';'||
                       i.barrio                ||';'||
                       i.departamento          ||';'||
                       i.cod_postal            ||';'||
                       i.telefono              ;
             IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
                v_buffer := v_buffer || v_eol || v_line;
             ELSE
                IF v_buffer IS NOT NULL THEN
                    UTL_FILE.PUT_LINE(v_file, v_buffer);
                END IF;
                v_buffer := v_line;
             END IF;
             EXIT WHEN PER_JURIDICAS%NOTFOUND;
         END LOOP;
         UTL_FILE.PUT_LINE(v_file, v_buffer);
               IF loop_operacion = 1 THEN
                 V_CAN_REG_1P:=0;
               else
                 V_CAN_REG_3T:=0;
               end if;
         v_line :=  'FIN ARCHIVO'    ||';'||
                    V_CAN_REG_1P     ||';'||
                    V_CAN_REG_3T     ||';'||
                    '0'              ||';'||
                    '0'              ||';'||
                    '0'              ||';'||
                    ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                    ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                    ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                    ';'||';'||';';
          UTL_FILE.PUT_LINE(v_file, v_line);
          UTL_FILE.FCLOSE(v_file);
          If v_generar = 'S' Then
              P_INS_WS(v_fec_actual,
                       v_cod_ente,
                       'J',
                       v_nom_archivo,
                       14, --Altas de Base Positiva
                       'zip');
              IF P_TIP_PROCESO = 'A' THEN
                 /*v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                                       v_port,
                                                       v_user,
                                                       v_pass,
                                                       v_repository,
                                                       v_nom_archivo||'.'||v_ext_archivo,
                                                       v_directorio||v_nom_archivo||'.'||v_ext_archivo);
              */null;
              ELSE
                 pr_com_archivo( v_nom_archivo, 'zip');
              END IF;
          Else
              UTL_FILE.fremove(v_repository,v_nom_archivo||'.'||v_ext_archivo);
          End If;
          v_lines := v_lines + 1;
       end loop;
     End If;
     -- Act de Personas Juridicas
     If (P_TIP_ARCHIVO = 'ACT_PER_JURIDICAS' or P_TIP_ARCHIVO = 'TODOS') 
       AND nvl(v_inf_PJ,'N')='S' Then
         v_line       := null;
         --Primera Vez se informa todo como 'I'
         IF nvl(v_pri_vez,'N') ='S'  then
              V_TIP_ARCHIVO := 'I';
         ELSE
               V_TIP_ARCHIVO := 'M';
         END IF;
         v_generar    := 'N';
         v_linetit    := null;
         v_can_reg_1p := 0;
         v_can_reg_3t := 0;
         v_buffer     := null;
         IF UTL_FILE.IS_OPEN(V_FILE) THEN
            UTL_FILE.FCLOSE(V_FILE);
         END IF;
         --v_nom_archivo  := LPAD(v_cod_ente, 6, '0')||'_EMPRESAS_ACT_'||to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'MMYYYY');
         FOR loop_operacion IN 1..2 LOOP
            -- Determinar el valor de v_nom_archivo en cada iteraci n
            IF loop_operacion = 1 THEN
                v_tip_operacion := 'T';
                v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_EMPRESAS_ACT_TARJETA_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
            ELSE
                -- Para la segunda iteraci n, cambiar el valor de v_nom_archivo
                v_tip_operacion := 'P';
                v_nom_archivo := LPAD(v_cod_ente, 6, '0') || '_EMPRESAS_ACT_PRESTAMO_' || TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL(6), 'MMYYYY');
            END IF;
         v_file := UTL_FILE.FOPEN(v_repository,v_nom_archivo||'.'||v_ext_archivo,'W',32767);
         -- Cabecera
         v_linetit := v_cod_ente                 ||';'||
                     CASE
                      WHEN v_tip_operacion = 'T' THEN '02'            ||';'
                      ELSE                            '01'            ||';'
                     END  ||
                     'INICIO ARCHIVO'            ||';'||
                     'ACTUALIZACIONES EMPRESAS'  ||';'||
                     to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMMDD')||';'||
                     to_char(sysdate,'HHMMSS')||';'||
                     to_char(pag_cal.FU_OBT_FEC_ACTUAL(6),'YYYYMM')||';'||
                     ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                     ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                     ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                     ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                     ';'||';'||';'||';'||';'||';';
         utl_file.put_line(v_file,v_linetit);
         v_error := 'PER_JURIDICAS_02';
         v_buffer     := null;
         FOR i IN PER_JURIDICAS LOOP
             v_generar := 'S';
             If i.tip_transaccion = '1P' Then
                  v_can_reg_1p :=  v_can_reg_1p + 1;
             Elsif i.tip_transaccion = '3T' Then
                  v_can_reg_3t :=  v_can_reg_3t + 1;
             End If;
             if nvl(v_pri_vez,'N') ='S'  then
                 v_tip_accion:='I';
               else
                 v_tip_accion:=i.tip_accion;
               end if;
             --v_tip_accion := fu_obt_tip_accion(i.id_operacion, i.periodo);
             v_line := v_tip_accion            ||';'||
                       i.cod_sucursal          ||';'||
                       i.tip_transaccion       ||';'||
                       i.id_operacion          ||';'||
                       i.tip_vinculacion       ||';'||
                       i.nro_cliente           ||';'||
                       i.can_dia_atraso        ||';'||
                       i.ope_cerrada           ||';'||
                       i.periodo               ||';'||
                       i.consentimiento        ||';'||
                       i.comp_mes              ||';'||
                       i.sal_total             ||';'||
                       i.refuerzos             ||';'||
                       i.can_cuo_pendientes    ||';'||
                       i.cuo_mes               ||';'||
                       i.sal_vencido           ||';'||
                       i.cod_mon_detalle       ||';'||
                       i.est_deuda             ||';'||
                       ''                      ||';'||-- Operación Cedida
                       ''                      ||';'||-- RUC
                       ''                      ||';'||-- Razón Social
                       ''                      ||';'||-- Vacío 1
                       ''                      ||';'||-- Vacío 2
                       ''                      ||';'||-- Vacío 3
                       ''                      ||';'||-- Vacío 4
                       ''                      ||';'||-- Vacío 5
                       ''                      ||';'||-- Vacío 6
                       ''                      ||';'||-- Vacío 7
                       CASE
                        WHEN v_tip_operacion = 'T' THEN i.mto_capital||';'
                        ELSE null
                       END                     || -- linea 29 de detalle de tarjetas - limite de credito/compra
                       i.fec_valor             ||';'|| -- FechaValorInfoEmpresa
                       i.tip_documento         ||';'||
                       i.cod_pai_documento     ||';'||
                       i.nro_documento         ||';'||
                       i.raz_social            ||';'||
                       i.nom_empresa           ||';'||
                       i.act_comercial         ||';'||
                       i.ini_actividades       ||';'||
                       i.calle                 ||';'||
                       i.nro_puerta            ||';'||
                       i.apartamento           ||';'||
                       i.piso                  ||';'||
                       i.complemento           ||';'||
                       i.kilometro             ||';'||
                       i.manzana               ||';'||
                       i.lote                  ||';'||
                       i.block                 ||';'||
                       i.esquina1              ||';'||
                       i.esquina2              ||';'||
                       i.tip_vivienda          ||';'||
                       i.id_ciudad             ||';'||
                       i.ciudad                ||';'||
                       i.barrio                ||';'||
                       i.departamento          ||';'||
                       i.cod_postal            ||';'||
                       i.telefono              ||
                       CASE -- Datos al cierre, solo para tarjetas
                        WHEN v_tip_operacion = 'T' THEN
                                               ';'||
                          i.dia_atr_cierre     ||';'||
                          i.lim_cre_dis_cie    ||';'||
                          i.tot_com_cierre     ||';'||
                          i.sal_tot_cierre     ||';'||
                          i.sal_cuo_cierre     ||';'||
                          i.sal_ven_cierre     ||';'||
                          i.lim_cre_cierre
                        ELSE null
                       END ;
             IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
                v_buffer := v_buffer || v_eol || v_line;
             ELSE
                IF v_buffer IS NOT NULL THEN
                    UTL_FILE.PUT_LINE(v_file, v_buffer);
                END IF;
                v_buffer := v_line;
             END IF;
             EXIT WHEN PER_JURIDICAS%NOTFOUND;
         END LOOP;
         UTL_FILE.PUT_LINE(v_file, v_buffer);
             IF loop_operacion = 1 THEN
               V_CAN_REG_1P:=0;
             else
               V_CAN_REG_3T:=0;
             end if;
         v_line :=  'FIN ARCHIVO'    ||';'||
                    V_CAN_REG_1P     ||';'||
                    V_CAN_REG_3T     ||';'||
                    '0'              ||';'||
                    '0'              ||';'||
                    '0'              ||';'||
                    ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                    ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                    ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                    ';'||';'||';'||';'||';'||';'||';'||';'||';'||';'||
                    ';'||';'||';'||';'||';'||';'||';';
          UTL_FILE.PUT_LINE(v_file, v_line);
          UTL_FILE.FCLOSE(v_file);
          If v_generar = 'S' Then
              P_INS_WS(v_fec_actual,
                       v_cod_ente,
                       'J',
                       v_nom_archivo,
                       15, --Actualizaciones de Base Positiva.
                       'zip');
              IF P_TIP_PROCESO = 'A' THEN
                /*v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                                       v_port,
                                                       v_user,
                                                       v_pass,
                                                       v_repository,
                                                       v_nom_archivo||'.'||v_ext_archivo,
                                                       v_directorio||v_nom_archivo||'.'||v_ext_archivo);
              */null;
              ELSE
                pr_com_archivo( v_nom_archivo, 'zip');
              END IF;
          Else
              UTL_FILE.fremove(v_repository,v_nom_archivo||'.'||v_ext_archivo);
          End If;
          v_lines := v_lines + 1;
       end loop;
     End If;
      --***************************************************************************************
     --Actualizamos el par_dinámico de primera Vez(Descomentar Para pasar a Producción)
     --update ge_par_dinamicos a set a.val_parametro='N' where a.parametro='INF_PRI_ARC_EQUIFAX';
     COMMIT;
     
     If P_TIP_PROCESO = 'A' Then --> Solo se va enviar autom ticamente cuando se ejecuta el proceso autom tico
        if nvl(v_env_ws,'N') = 'S' then
          PRG_WSI_ENV_EQUIFAX(null, p_tip_proceso);
        end if;
     End If;
     
     
EXCEPTION
     When Others Then
          raise_application_error (-20000,'Error '||v_error||' - '||sqlerrm);
END;
/
