CREATE OR REPLACE PACKAGE BODY IT.PAG_CON IS
   /**********************
   -- Autor    : Milton Benitez
   -- Creado   : 03/2018
   -- Objetivo : Procesamiento de Datos Enviados a IT-GF desde otras aplicaciones, y enviar de IT-GF a Otras aplicaciones.
                 V1: Pre-Carga de Limites de Creditos desde el CRM a IT-GF.
   ***********************/

   /*Pre-Carga de LImites de Creditos*/
   FUNCTION FU_INS_LIN_CREDITO (P_MENSAJE GE_EXP_APLICACIONES_CAB.MENSAJE%TYPE) RETURN VARCHAR2 IS

     V_ID                   NUMBER;
     V_FECHA                GE_EXP_APLICACIONES_CAB.FECHA%TYPE := PAG_CAL.FU_OBT_FEC_ACTUAL(P_COD_MODULO => 1);
     V_HORA                 GE_EXP_APLICACIONES_CAB.HORA%TYPE  := TO_CHAR(SYSDATE,'HH24:MM:SS');
     V_RESPUESTA            GE_EXP_APLICACIONES_CAB.RESPUESTA%TYPE := '{"DATOS": { ';
     V_COD_ERROR            VARCHAR2(4) := '0000';
     V_MENSAJE              GE_EXP_APLICACIONES_CAB.RESPUESTA%TYPE;
     V_EXISTE               VARCHAR2(1) := 'N';
     V_NRO_LINEA            PR_LINEAS.NRO_LINEA%TYPE;
     V_URL                  GE_EXP_APLICACIONES_CAB.URL_CRM%TYPE;
     V_GUID_CRM             GE_EXP_APLICACIONES_CAB.GUID_CRM%TYPE;
     V_COD_USU_SOLICITANTE  VARCHAR2(20) ;
     V_COD_USU_SANCIONADOR  VARCHAR2(20) ;
     CURSOR C_LINEAS (P_ID NUMBER) IS
         SELECT DISTINCT t.cod_persona,
                         t.cod_moneda,
                         t.mto_producto,
                         pag_cal.FU_OBT_FEC_ACTUAL(1) + t.plazo fec_vencimiento,
                         'CAPITAL OPERATIVO' descripcion,
                         nvl(t.cod_campana,'877') cod_campana,
                         t.nro_sol_crm nro_acta

           FROM GE_EXP_APLICACIONES_DET t
          WHERE t.COD_MENSAJE   = P_ID
            and t.tip_operacion = 'L' --> Solo Linea de Credito
            and rownum = 1;

     CURSOR C_LIN_GARANTIAS(P_ID          NUMBER  ,
                            P_COD_PERSONA VARCHAR2,
                            P_COD_MONEDA  VARCHAR2,
                            P_MTO_LIMITE  NUMBER  ) IS
         SELECT T.TIP_GARANTIA,
                t.mto_gar_aplicado MTO_GARANTIA,
                MAX(MTO_SUB_PRODUCTO) MTO_SUB_PRODUCTO
           FROM GE_EXP_APLICACIONES_DET t
          WHERE t.cod_persona   = p_cod_persona
            AND t.cod_moneda    = p_cod_moneda
            AND t.Mto_Producto  = p_mto_limite
            AND T.TIP_OPERACION = 'L' --> Solo Linea de Credito
            AND T.COD_MENSAJE   = P_ID
         Group By T.TIP_GARANTIA, T.MTO_GAR_APLICADO;

     CURSOR C_LIN_PRODUCTOS (P_ID           NUMBER,
                             P_TIP_GARANTIA VARCHAR2) IS
         SELECT t.cod_persona,
                t.cod_moneda,
                t.mto_producto,
                t.cod_modulo,
                t.cod_modalidad,
                t.mto_sub_producto,
                t.tip_garantia
           FROM GE_EXP_APLICACIONES_DET t
          WHERE T.COD_MENSAJE   = P_ID
            AND T.TIP_OPERACION = 'L' --> Solo L?nea de Credito
            AND T.TIP_GARANTIA  = P_TIP_GARANTIA;
          V_COD_MODALIDAD GE_MODALIDADES.COD_MODALIDAD%TYPE;
   BEGIN
         PRE_CAM_FOR_NUMERICO(',.');
         If P_MENSAJE is null Then
            V_COD_ERROR := '0001';
            V_MENSAJE   := 'El Mensaje Recibido es nulo.';
         End If;
         If nvl(V_COD_ERROR,'0000') = '0000' Then
            PR_INS_MENSAJE(V_FECHA              ,
                           V_HORA               ,
                           P_MENSAJE            ,
                           V_ID                 ,
                           V_URL                ,
                           V_GUID_CRM           ,
                           V_COD_USU_SOLICITANTE,
                           V_COD_USU_SANCIONADOR,
                           V_COD_ERROR          ,
                           V_MENSAJE            );
         End If;
         If nvl(V_COD_ERROR,'0000') = '0000' Then
             For d in C_LINEAS (V_ID) Loop
                 IF d.cod_persona IS NULL THEN
                    V_COD_ERROR := '0005';
                    V_MENSAJE := 'El codigo de persona no puede ser nulo.';
                 END IF;
                 IF d.cod_moneda IS NULL THEN
                    V_COD_ERROR := '0006';
                    V_MENSAJE := 'El codigo de moneda no puede ser nulo.';
                 END IF;
                 IF NVL(d.mto_producto, 0) <= 0 THEN
                    V_COD_ERROR := '0007';
                    V_MENSAJE := 'El monto de la linea debe ser mayor a cero.';
                 END IF;
                 IF d.fec_vencimiento IS NULL OR d.fec_vencimiento <= V_FECHA THEN
                    V_COD_ERROR := '0008';
                    V_MENSAJE := 'La fecha de vencimiento no puede ser nula o menor o igual a la fecha de hoy.';
                 END IF;
                 IF d.descripcion IS NULL THEN
                    V_COD_ERROR := '0009';
                    V_MENSAJE := 'La descripcion de la linea no puede ser nula.';
                 END IF;
                 -- Si fue vendido bajo una campana, se verifica que la campana este vigente
                 If nvl(d.cod_campana,'877') <> '877' Then
                     BEGIN
                       SELECT 'S'
                         INTO v_existe
                         FROM cr_campanas c
                        WHERE c.cod_campana = d.cod_campana
                          AND V_FECHA BETWEEN c.fec_inicio AND c.fec_vencimiento;
                     EXCEPTION
                       WHEN OTHERS THEN
                            v_existe := 'N';
                     END;
                     IF v_existe = 'N' THEN
                         V_COD_ERROR := '0010';
                         V_MENSAJE   := 'La campana ingresada no existe o no esta vigente.';
                     END IF;
                 End If;
                 -- Insertar Cabecera de la Linea.
                 If NVL(V_COD_ERROR,'0000') = '0000' Then
                    SELECT S_NRO_LINEA.NEXTVAL
                      INTO V_NRO_LINEA
                      FROM DUAL;
                    BEGIN
                       INSERT INTO PR_LINEAS( nro_linea        ,
                                              cod_persona      ,
                                              cod_moneda       ,
                                              monto            ,
                                              fec_vencimiento  ,
                                              fec_otorgamiento ,
                                              mto_aplicado     ,
                                              descripcion      ,
                                              estado           ,
                                              cotizacion       ,
                                              cod_campana      ,
                                              Nro_Acta         ,
                                              Url_Crm          )
                                      VALUES( v_nro_linea      ,
                                              d.cod_persona    ,
                                              d.cod_moneda     ,
                                              d.mto_producto   ,
                                              d.fec_vencimiento,
                                              v_fecha          ,
                                              0                ,
                                              d.descripcion    ,
                                              'P'              ,
                                              pag_gen.fu_obt_cotizacion(pag_gen.FU_OBT_MON_FUERTE(),v_fecha),
                                              d.cod_campana    ,
                                              d.nro_acta       ,
                                              V_URL            );
                    EXCEPTION
                       WHEN OTHERS THEN
                             V_COD_ERROR := '0011';
                             V_MENSAJE   := 'Error al insertar la linea de credito.'||sqlerrm;
                    END;
                    -- Si no hubo errores Insertar Garantias de la Linea.
                    If NVL(V_COD_ERROR,'0000') = '0000' Then
                       For g in C_LIN_GARANTIAS(V_ID          ,
                                                d.cod_persona ,
                                                d.cod_moneda  ,
                                                d.mto_producto) LOOP
                           IF NVL(g.mto_sub_producto, 0) <= 0 OR g.mto_sub_producto > d.mto_producto THEN
                              V_COD_ERROR := '0012';
                              V_MENSAJE := 'El monto limite por modalidad debe ser mayor a cero y menor o igual al monto limite.';
                           END IF;
                           --Verifica que exista el tipo de garantia ingresado
                           BEGIN
                              SELECT 'S'
                                INTO v_existe
                                FROM pr_gar_tipos
                               WHERE cod_garantia = g.tip_garantia
                                 AND NVL(activo, 'N') = 'S';
                           EXCEPTION
                             WHEN OTHERS THEN
                               v_existe := 'N';
                           END;
                           IF v_existe = 'N' THEN
                              V_COD_ERROR := '0013';
                              V_MENSAJE   := 'El tipo de garantia no existe o no esta activo. '||g.tip_garantia;
                           END IF;
                           -- Si la verificaci?n fue satisfactoria se inserta el registro de Garantia.
                           If NVL(V_COD_ERROR,'0000') = '0000' Then
                              BEGIN
                                 INSERT INTO PR_LIN_TIP_GARANTIAS( NRO_LINEA    ,
                                                                   COD_GARANTIA ,
                                                                   MTO_LIMITE   ,
                                                                   MTO_APLICADO ,
                                                                   REL_GARANTIA )
                                                           VALUES( V_NRO_LINEA       ,
                                                                   g.tip_garantia    ,
                                                                   --g.mto_sub_producto,
                                                                   g.MTO_GARANTIA,
                                                                   0                 ,
                                                                   1                 );
                               EXCEPTION
                                   WHEN OTHERS THEN
                                       V_COD_ERROR := '0014';
                                       V_MENSAJE   := ('Error al insertar el tipo de garantia de la linea de credito. - '||sqlerrm);
                               END;
                               -- Si no hubo errores insertar los productos.
                               If NVL(V_COD_ERROR,'0000') = '0000' Then
                                  For p in C_LIN_PRODUCTOS (V_ID          ,
                                                            G.TIP_GARANTIA) Loop
                                      IF p.cod_modulo IS NULL THEN
                                          V_COD_ERROR := '0015';
                                          V_MENSAJE := 'El codigo del modulo no puede ser nulo.';
                                      END IF;
                                      --Verifica que el modulo y modalidad esten habilitados para lineas de credito
                                      IF p.cod_modulo    = 5 Then
                                         V_COD_MODALIDAD := 51;
                                      ELSIF p.cod_modulo = 7 Then
                                         V_COD_MODALIDAD := 70;
                                      ELSIF p.cod_modulo = 8 Then
                                         V_COD_MODALIDAD := 81;
                                      ELSE
                                         V_COD_MODALIDAD := p.cod_modalidad;
                                      END IF;
                                      IF NVL(fug_obt_pardinamico('LIM_PRO_HABILITADOS', p.cod_modulo, V_COD_MODALIDAD), 'N') <> 'S' THEN
                                        V_COD_ERROR := '0016';
                                        V_MENSAJE   := 'El modulo y la modalidad no existen o no estan habilitados para ingreso de lineas de credito.';
                                      END IF;
                                      -- Si no hubo errores en la verificaci?n inserta los registros.
                                      If NVL(V_COD_ERROR,'0000') = '0000' Then
                                         BEGIN
                                           IF p.cod_modulo IN (5,8) THEN
                                              V_COD_MODALIDAD := Null;
                                           END IF;
                                           INSERT INTO PR_LIN_TIP_GAR_MAD( NRO_LINEA       ,
                                                                           COD_GARANTIA    ,
                                                                           COD_MODULO      ,
                                                                           COD_MODALIDAD   ,
                                                                           MTO_LIMITE      ,
                                                                           MTO_APLICADO    )
                                                                   VALUES( V_NRO_LINEA     ,
                                                                           g.TIP_GARANTIA  ,
                                                                           p.COD_MODULO    ,
                                                                           V_COD_MODALIDAD ,
                                                                           P.MTO_SUB_PRODUCTO,
                                                                           0               );
                                         EXCEPTION
                                           WHEN OTHERS THEN
                                                 V_COD_ERROR := '0017';
                                                 V_MENSAJE   := 'Error al insertar los Sub-Productos de la linea de credito. - '||sqlerrm;
                                         END;
                                      End If;
                                  End Loop;
                               End If;
                           End If;
                       END LOOP;
                    end If;
                 End If;
             End Loop;
         End If;
         
         --control guid crm
         if g_guid_crm is not null then
           v_guid_crm := g_guid_crm;
         end if;
         
         v_mensaje := pag_con.FU_OBT_MSJ_ERROR(v_mensaje);
         
         V_MENSAJE := REPLACE (V_MENSAJE,CHR(34),'-');
         If NVL(V_COD_ERROR,'0000') = '0000' Then
             V_MENSAJE   := V_NRO_LINEA;
             V_RESPUESTA := (V_RESPUESTA||'"COD_RESPUESTA":'||NVL(V_COD_ERROR,'"0000", ')
                                        ||'"ESTADO": "P",'
                                        ||'"ARCHIVO": "'||g_ARCHIVO||'", '
                                        ||'"MENSAJE": "'||V_MENSAJE||'", '
                                        ||'"GUID": "'   ||V_GUID_CRM||'"}}');
             Begin
                update GE_EXP_APLICACIONES_CAB x
                   set x.estado              = 'P',
                       x.respuesta           = V_RESPUESTA,
                       x.url_crm             = v_url,
                       x.cod_usu_solicitante = SUBSTR (V_COD_USU_SOLICITANTE, 0, 10),
                       x.cod_usu_sancionador = SUBSTR (V_COD_USU_SANCIONADOR, 0, 10),
                       x.guid_crm            = V_GUID_CRM
                 Where x.COD_MENSAJE         = V_ID;
             Exception
                 When Others Then
                      V_COD_ERROR := '0018';
                      V_MENSAJE   := 'Error al actualizar al estado Procesado '||Sqlerrm;
             End;
             COMMIT;
         Else
             V_RESPUESTA := (V_RESPUESTA||'"COD_RESPUESTA":"'||NVL(V_COD_ERROR,'"0000","')||'", '
                                        ||'"ESTADO": "E",'
                                        ||'"ARCHIVO": "'||g_ARCHIVO||'", '
                                        ||'"MENSAJE": "'||V_MENSAJE||'", '
                                        ||'"GUID": "'   ||V_GUID_CRM||'"}}');
             RollBack; --Vuelvo atras lo realizado en cuanto a la insercion de lineas
             Begin
                update GE_EXP_APLICACIONES_CAB x
                   set x.estado      = 'E',
                       x.respuesta   = V_RESPUESTA
                 Where x.COD_MENSAJE = V_ID;
             Exception
                 When Others Then
                      V_COD_ERROR := '0019';
                      V_MENSAJE   := 'Error al actualizar al estado Erroneo '||Sqlerrm;
             End;
             COMMIT; --Guardo solo el error
         End If;
            --RETURN REPLACE (V_RESPUESTA,CHR(34),CHR(39));
            RETURN V_RESPUESTA;
         --End If;
   END FU_INS_LIN_CREDITO;

   /*Procedimiento de lectura de datos recibidos*/
   PROCEDURE PR_INS_MENSAJE (P_FECHA               IN DATE     ,
                             P_HORA                IN VARCHAR2 ,
                             P_DATOS               IN CLOB     ,
                             V_ID                  OUT NUMBER  ,
                             V_URL                 OUT VARCHAR2,
                             V_GUID_CRM            OUT VARCHAR2,
                             V_COD_USU_SOLICITANTE OUT VARCHAR2,
                             V_COD_USU_SANCIONADOR OUT VARCHAR2,
                             V_COD_ERROR           OUT VARCHAR2,
                             V_MENSAJE             OUT VARCHAR2) IS
   V_ERROR      VARCHAR2(4000);
   -----
   PROCEDURE PR_INS_DETALLE (P_ID                  IN NUMBER   ,
                             P_URL                 OUT VARCHAR2,
                             P_GUID_CRM            OUT VARCHAR2,
                             P_COD_USU_SOLICITANTE OUT VARCHAR2,
                             P_COD_USU_SANCIONADOR OUT VARCHAR2,
                             V_COD_ERROR           OUT VARCHAR2,
                             V_MENSAJE             OUT VARCHAR2) IS
        v_fecha                date := pag_cal.FU_OBT_FEC_ACTUAL(1);
        v_hora                 varchar2(10) := to_char(sysdate,'HH24:SS:MM');
        v_cod_persona          GE_EXP_APLICACIONES_DET.Cod_Persona%type;
        v_nro_sol_crm          varchar2(10);
        v_guid_crm             varchar2(3000);
        v_mod_crm              varchar2(50);
        v_tip_operacion        GE_EXP_APLICACIONES_DET.tip_operacion%type;
        v_cod_modulo           GE_EXP_APLICACIONES_DET.Cod_Modulo%type;
        v_cod_modalidad        GE_EXP_APLICACIONES_DET.Cod_Modalidad%type;
        v_cod_moneda           GE_EXP_APLICACIONES_DET.Cod_Moneda%type;
        v_monto                GE_EXP_APLICACIONES_DET.Mto_Producto%type;
        v_mto_sub              GE_EXP_APLICACIONES_DET.Mto_Sub_Producto%type;
        v_cod_campana          GE_EXP_APLICACIONES_DET.Cod_Campana%type;
        v_cod_oficina          GE_EXP_APLICACIONES_DET.Cod_Oficina%type;
        v_plazo                GE_EXP_APLICACIONES_DET.Plazo%type;
        v_tip_venta            GE_EXP_APLICACIONES_DET.Tip_Venta%type;
        v_tip_garantia         GE_EXP_APLICACIONES_DET.Tip_Garantia%type;
        v_cod_per_garante      GE_EXP_APLICACIONES_DET.Cod_Per_Garante%type;
        v_mto_gar_aplicado     GE_EXP_APLICACIONES_DET.Mto_Gar_Aplicado%type;
        -----------------------------
        v_existe               varchar2(1) := 'N';
        v_nom_tabla            ge_arc_campos.nom_tabla%type;
        v_campo                ge_arc_campos.campo%type;
        v_nro_sol_it           pr_solicitudes.nro_solicitud%type;
        v_cod_resp_crm         ge_exp_aplicaciones_cab.respuesta%type;
        v_cod_mensaje          ge_exp_aplicaciones_cab.cod_mensaje%type;
        v_ref_cursor           sql_util.t_cursor_tab;
        v_filas                number;
        v_error                varchar2(4000);
        v_sentencia            varchar2(4000);
        -----------------------------
        v_jdatos0    typ_json;
        v_jdatos1    typ_json;
        v_jdatos2    typ_json;
        v_jdatos3    typ_json;
        v_jdatos4    typ_json;
        v_jdatos5    typ_json;
        v_jdatos6    typ_json;
        v_jdatos7    typ_json;

        v_vdato0     typ_jsonvalue;
        v_vdato1     typ_jsonvalue;
        v_vdato2     typ_jsonvalue;
        v_vdato3     typ_jsonvalue;
        v_vdato4     typ_jsonvalue;

        v_ldato0     typ_jsonlist;
        v_ldato1     typ_jsonlist;
        v_ldato2     typ_jsonlist;
        -----------------------------
        v_ver_persona ba_personas.cod_persona%type;
        v_ver_usuario ba_usuarios.cod_usuario%type;
        v_lugar       varchar2(100);
        -----------------------------
        CURSOR DATOS IS
             SELECT A.MENSAJE DATO
             FROM GE_EXP_APLICACIONES_CAB A
              WHERE A.COD_MENSAJE = P_ID;

        FUNCTION F_OBT_GARANTIA (P_CADENA IN VARCHAR2) RETURN NUMBER IS
             V_TIP_GARANTIA GE_EXP_APLICACIONES_DET.Tip_Garantia%type;
        BEGIN
            Select cod_garantia
              into v_tip_garantia
            from pr_gar_tipos a
            where a.cod_garantia = P_CADENA;
            RETURN v_tip_garantia;
        EXCEPTION
            When no_data_found Then
                 v_tip_garantia := 0;
                 RETURN v_tip_garantia;
        END F_OBT_GARANTIA;
      PROCEDURE P_INS_DATOS(P_id               IN GE_EXP_APLICACIONES_DET.COD_MENSAJE%type,
                            P_fecha            IN GE_EXP_APLICACIONES_DET.FECHA%TYPE,
                            P_hora             IN GE_EXP_APLICACIONES_DET.HORA%TYPE,
                            P_nro_sol_crm      IN varchar2,
                            P_cod_persona      IN GE_EXP_APLICACIONES_DET.COD_PERSONA%TYPE,
                            P_tip_operacion    IN GE_EXP_APLICACIONES_DET.TIP_OPERACION%TYPE,
                            P_tip_venta        IN GE_EXP_APLICACIONES_DET.TIP_VENTA%TYPE,
                            P_cod_moneda       IN GE_EXP_APLICACIONES_DET.COD_MONEDA%TYPE,
                            P_monto            IN GE_EXP_APLICACIONES_DET.MTO_PRODUCTO%TYPE,
                            P_plazo            IN GE_EXP_APLICACIONES_DET.PLAZO%TYPE,
                            P_fec_aprobacion   IN GE_EXP_APLICACIONES_DET.FECHA%TYPE,
                            P_tip_garantia     IN GE_EXP_APLICACIONES_DET.TIP_GARANTIA%TYPE,
                            P_cod_per_garante  IN GE_EXP_APLICACIONES_DET.COD_PER_GARANTE%TYPE,
                            P_mto_gar_aplicado IN GE_EXP_APLICACIONES_DET.MTO_GAR_APLICADO%TYPE,
                            P_cod_modulo       IN GE_EXP_APLICACIONES_DET.COD_MODULO%TYPE,
                            P_cod_modalidad    IN GE_EXP_APLICACIONES_DET.COD_MODALIDAD%TYPE,
                            P_mto_sub          IN GE_EXP_APLICACIONES_DET.MTO_SUB_PRODUCTO%TYPE,
                            P_cod_campana      IN GE_EXP_APLICACIONES_DET.COD_CAMPANA%TYPE,
                            P_cod_oficina      IN GE_EXP_APLICACIONES_DET.COD_OFICINA%TYPE,
                            P_mod_crm          IN varchar2,
                            V_COD_ERROR        OUT VARCHAR2,
                            V_MENSAJE          OUT VARCHAR2) IS
          PRAGMA AUTONOMOUS_TRANSACTION;
          BEGIN
              Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; End;
              BEGIN
                    Insert into GE_EXP_APLICACIONES_DET(COD_MENSAJE     ,
                                                        FECHA           ,
                                                        HORA            ,
                                                        NRO_SOL_CRM     ,
                                                        COD_PERSONA     ,
                                                        TIP_OPERACION   ,
                                                        TIP_VENTA       ,
                                                        COD_MONEDA      ,
                                                        MTO_PRODUCTO    ,
                                                        PLAZO           ,
                                                        FEC_APROBACION  ,
                                                        TIP_GARANTIA    ,
                                                        COD_PER_GARANTE ,
                                                        MTO_GAR_APLICADO,
                                                        COD_MODULO      ,
                                                        COD_MODALIDAD   ,
                                                        MTO_SUB_PRODUCTO,
                                                        COD_CAMPANA     ,
                                                        COD_OFICINA     )
                                                 Values(p_id              ,
                                                        P_fecha           ,
                                                        P_hora            ,
                                                        to_number(P_nro_sol_crm),
                                                        P_cod_persona     ,
                                                        P_tip_operacion   ,
                                                        P_tip_venta       ,
                                                        P_cod_moneda      ,
                                                        P_monto           ,
                                                        P_plazo           ,
                                                        P_fec_aprobacion  ,
                                                        P_tip_garantia    ,
                                                        P_cod_per_garante ,
                                                        P_mto_gar_aplicado,
                                                        P_cod_modulo      ,
                                                        P_cod_modalidad   ,
                                                        P_mto_sub         ,
                                                        P_cod_campana     ,
                                                        P_cod_oficina     );
                     COMMIT;
              EXCEPTION
                     WHEN Others Then
                          V_COD_ERROR := '0004';
                          V_MENSAJE   := 'Error al Insertar Detalle - '||sqlerrm;
              END;
              If nvl(P_mod_crm,'XX') = 'OPORTUNIDAD' Then
                 --Insertar en la nueva tabla
                 Begin
                     null;
                 Exception
                     When Others Then
                          null;
                 End;

              End If;
           END P_INS_DATOS;

    PROCEDURE P_PRO_DAT_DINAMICOS(P_JSON             IN CLOB
                                    ,P_GUID_CRM         OUT VARCHAR2
                                    ,P_COD_ERROR        OUT VARCHAR2
                                    ,P_MENSAJE          OUT VARCHAR2) IS
             --mebsaje json
             V_MENSAJE clob;

             --variables de valor json
             --VALOR_STR varchar2(2000);
             --VALOR_NUM number;

             --variables de uso fijo
             V_PARAM1  number;
             V_PARAM2 VARCHAR2(100);
             V_ARCHIVO varchar2(500);
             V_URL_CRM varchar2(2000);


             --variables para el manejo de las partes del json
             --V_JSONLIST TYP_JSONLIST;

             V_JSON_DATA      TYP_JSONVALUE;
             V_JSON_META_DATA TYP_JSONVALUE;
             V_JSON_CABECERA  TYP_JSONVALUE;
             V_JSON_DETALLE   TYP_JSONVALUE;

             --variable de valor tipo json
             V_JSON_VALOR TYP_JSONVALUE;

             --mensaje json en tipo json
             V_JSON_MENSAJE TYP_JSON;

             --variables de json en tipo objeto json
             V_JSON_DATA_OBJ      TYP_JSON;
             V_JSON_META_DATA_OBJ TYP_JSON;
             V_JSON_CABECERA_OBJ  TYP_JSON;
             V_JSON_DETALLE_OBJ   TYP_JSON;

             --VARIABLES AUX
             V_TAG           varchar2(2000);
             V_CAMPO_MENSAJE varchar2(2000);
             V_JSON_OBJ      TYP_JSON;

             V_JSON_OBJ_NIV1 TYP_JSON;
             V_JSON_OBJ_NIV2 TYP_JSON;
             V_JSON_OBJ_NIV3 TYP_JSON;
             --V_JSON_OBJ_NIV4 TYP_JSON;

             --VALORES DE TABLA DINAMICA
             V_EXISTE    varchar2(1) := 'N';
             V_NOM_TABLA GE_ARC_CAMPOS.NOM_TABLA%type;
             V_CAMPO     GE_ARC_CAMPOS.CAMPO%type;
             V_FUNCION   GE_ARC_CAMPOS.FUNCION%type;
             V_FORMATO   varchar2(2000);

             V_SENTENCIA varchar2(4000);
             --V_SENTENCIA2 varchar2(4000);
             V_COLUMNAS varchar2(4000);
             V_VALORES  varchar2(4000);

             V_COLUMNAS1 varchar2(4000);
             V_VALORES1  varchar2(4000);

             V_COLUMNAS2 varchar2(4000);
             V_VALORES2  varchar2(4000);

             V_COLUMNAS3 varchar2(4000);
             V_VALORES3  varchar2(4000);

             V_VALOR_AUX varchar2(4000);

             --V_PROFUNDIDAD number := 0;
             --V_RUTA        varchar2(2000);
             --V_ITEMS       number;

             --insercion ordenada de sql
             type HASH_MAP is table of varchar2(4000) index by varchar2(30);
             --V_SQLS_MAP  HASH_MAP;
             V_SQL_CAB   HASH_MAP;
             V_SQL_NIV_0 HASH_MAP;
             V_SQL_NIV_1 HASH_MAP;
             V_SQL_NIV_2 HASH_MAP;
             V_SQL_NIV_3 HASH_MAP;

             I           varchar2(4000);
             V_COUNT_SQL number(20) := 0;

             V_SQL   varchar2(4000);
             V_ERROR varchar2(4000);

             function FU_EXE_FUNCION(P_FUNCION   in varchar2
                                    ,P_PARAMETRO in varchar2) return varchar2 is

                V_RESULTADO varchar2(2000);
             begin
                /*execute immediate P_FUNCION
                into v_resultado
                using P_PARAMETRO;*/

                execute immediate 'begin :result := ' || P_FUNCION || '; end;'
                   using out V_RESULTADO, P_PARAMETRO;

                return V_RESULTADO;
             exception
                when others then
                   RAISE_APPLICATION_ERROR(-20001, 'Error al ejecutar funcion dinamica. ' || sqlerrm);
             end;

             procedure PR_CAM_DINAMICO(P_ARCHIVO       in varchar2
                                      ,P_TAG           in varchar2
                                      ,P_CAMPO_MENSAJE in varchar2
                                      ,P_EXISTE        out varchar2
                                      ,P_NOM_TABLA     out varchar2
                                      ,P_CAMPO         out varchar2
                                      ,P_FUNCION       out varchar2
                                      ,P_FORMATO       out varchar2) is
             begin
                begin
                   select distinct 'S'
                                  ,A.NOM_TABLA
                                  ,A.CAMPO
                                  ,A.FUNCION
                                  ,A.FORMATO
                     into P_EXISTE
                         ,P_NOM_TABLA
                         ,P_CAMPO
                         ,P_FUNCION
                         ,P_FORMATO
                     from GE_ARC_CAMPOS A
                    where A.REFERENCIA = P_ARCHIVO
                      and A.TIP_DATO = P_TAG
                      and UPPER(A.DESCRIPCION) = UPPER(P_CAMPO_MENSAJE);
                exception
                   when NO_DATA_FOUND then
                      V_EXISTE := 'N';
                   when others then
                      P_COD_ERROR := '0027';
                      P_MENSAJE   := 'Error al buscar configuracion dinamica ' || sqlerrm;
                end;
             end;

             procedure PR_SENTENCIA_SQL(P_EXISTE    in varchar2
                                       ,P_CAMPO     in varchar2
                                       ,P_NOM_TABLA in varchar2
                                       ,P_FORMATO   in varchar2
                                       ,P_VALOR_AUX in varchar2
                                       ,P_COLUMNAS  in out varchar2
                                       ,P_VALORES   in out varchar2) is
                V_VALOR_AUX varchar2(2000) := P_VALOR_AUX;
             begin
               /*if V_VALOR_AUX is null then 
                 V_VALOR_AUX:= '';
               end if;*/
                if P_EXISTE = 'S' then
                   --COLUMNAS
                   if P_COLUMNAS is null then
                      P_COLUMNAS := 'INSERT INTO ' || P_NOM_TABLA || ' (' || P_CAMPO;
                   else
                      P_COLUMNAS := P_COLUMNAS || ',' || P_CAMPO;
                   end if;

                   --VALORES
                   --en caso de que el valor tenga que ser obtenido mediante funcion
                   if V_FUNCION is not null then
                      V_VALOR_AUX := FU_EXE_FUNCION(V_FUNCION, V_PARAM1);
                      --AL SER TIPO DE DATO STRING
                      IF nvl(P_FORMATO,'STRING') NOT IN ('NUMBER','DATE') THEN
                          --Y LA FUNCION NO RETORNA NADA, VOLVER A ASIGNAR EL VALOR ORIGINAL DEL DATO
                          IF V_VALOR_AUX IS NULL THEN
                            V_VALOR_AUX := P_VALOR_AUX;
                          END IF;
                      END IF;
                   end if;

                   if P_VALORES is null then
                      --verifica si es fecha
                      if P_FORMATO = 'DATE' then
                         --instr(v_valor_aux,'/',1,2) = 6 and instr(v_valor_aux,'/',1,1) = 3 then
                         V_VALOR_AUX := replace('to_date(' || CHR(39) || V_VALOR_AUX || CHR(39) || ',' ||
                                                CHR(39) || 'dd/mm/rrrr' || CHR(39) || ')',
                                                ' ',
                                                '');
                         P_VALORES   := ') VALUES (' || V_VALOR_AUX;
                      elsif P_FORMATO = 'NUMBER' then
                         P_VALORES := ') VALUES (' || nvl(V_VALOR_AUX,'''''');
                      else
                         P_VALORES := ') VALUES (' || CHR(39) || V_VALOR_AUX || CHR(39);
                      end if;

                   else
                      --verifica si es fecha
                      if P_FORMATO = 'DATE' then
                         --instr(v_valor_aux,'/',1,2) = 6 and instr(v_valor_aux,'/',1,1) = 3 then
                         V_VALOR_AUX := replace('to_date(' || CHR(39) || V_VALOR_AUX || CHR(39) || ',' ||
                                                CHR(39) || 'dd/mm/rrrr' || CHR(39) || ')',
                                                ' ',
                                                '');
                         P_VALORES   := P_VALORES || ',' || V_VALOR_AUX;
                      elsif P_FORMATO = 'NUMBER' then
                         P_VALORES := P_VALORES || ',' || nvl(V_VALOR_AUX,'''''');
                      else
                         P_VALORES := P_VALORES || ',' || CHR(39) || V_VALOR_AUX || CHR(39);
                      end if;
                   end if;

                end if;
             end;

          begin

             V_MENSAJE := P_JSON;

             V_JSON_MENSAJE := TYP_JSON(V_MENSAJE);
             V_JSON_MENSAJE.PRINT;

             begin
               if V_JSON_MENSAJE.EXIST('DATA') then
                   V_JSON_DATA := V_JSON_MENSAJE.GET('DATA'); --SE CARGA EN JSON VALUE
                   if V_JSON_DATA.IS_OBJECT then
                      V_JSON_DATA_OBJ := TYP_JSON(V_JSON_DATA);
                   end if;
               end if;

                for C in 1 .. V_JSON_DATA_OBJ.COUNT loop
                   V_JSON_VALOR := V_JSON_DATA_OBJ.JSON_DATA(C);
                   V_TAG        := V_JSON_VALOR.MAPNAME;
                   DBMS_OUTPUT.PUT_LINE(V_TAG);
                   if V_TAG = 'METADATA' then
                      begin
                         V_JSON_META_DATA := V_JSON_DATA_OBJ.GET('METADATA'); --SE CARGA EN JSON VALUE

                         if V_JSON_META_DATA.IS_OBJECT then
                            V_JSON_META_DATA_OBJ := TYP_JSON(V_JSON_META_DATA); --SE CARGA EN JSON OBJETO

                            --PARAM1: OBTENEMOS EL VALOR
                            if V_JSON_META_DATA_OBJ.EXIST('PARAM1') then
                               V_JSON_VALOR := V_JSON_META_DATA_OBJ.GET('PARAM1'); --SE CARGA EN JSON VALUE
                               if V_JSON_VALOR is not null and V_JSON_VALOR.IS_STRING then
                                  V_PARAM1 := TO_NUMBER(V_JSON_VALOR.GET_STRING); --SE OBTIENE EL VALOR
                               end if;
                            end if;

                            --ARCHIVO: OBTENEMOS EL VALOR
                            if V_JSON_META_DATA_OBJ.EXIST('ARCHIVO') then
                               V_JSON_VALOR := V_JSON_META_DATA_OBJ.GET('ARCHIVO'); --SE CARGA EN JSON VALUE
                               if V_JSON_VALOR is not null and V_JSON_VALOR.IS_STRING then
                                  V_ARCHIVO := V_JSON_VALOR.GET_STRING; --SE OBTIENE EL VALOR
                                  g_archivo := v_archivo;
                               end if;
                            end if;

                            --PARAM2: OBTENEMOS EL VALOR (GUID)
                            if V_JSON_META_DATA_OBJ.EXIST('PARAM2') then
                               V_JSON_VALOR := V_JSON_META_DATA_OBJ.GET('PARAM2'); --SE CARGA EN JSON VALUE
                               if V_JSON_VALOR is not null and V_JSON_VALOR.IS_STRING then
                                  P_GUID_CRM := V_JSON_VALOR.GET_STRING; --SE OBTIENE EL VALOR
                                  G_GUID_CRM := P_GUID_CRM;
                               end if;
                            end if;

                            --URL CRM:
                            if V_JSON_META_DATA_OBJ.EXIST('URL') then
                               V_JSON_VALOR := V_JSON_META_DATA_OBJ.GET('URL'); --SE CARGA EN JSON VALUE
                               if V_JSON_VALOR is not null and V_JSON_VALOR.IS_STRING then
                                  V_URL_CRM := V_JSON_VALOR.GET_STRING; --SE OBTIENE EL VALOR
                                  g_url_crm := V_URL_CRM;
                               end if;
                            end if;
                            
                            --URL CRM: /**/
                            if V_JSON_META_DATA_OBJ.EXIST('PARAM3') then
                               V_JSON_VALOR := V_JSON_META_DATA_OBJ.GET('PARAM3'); --SE CARGA EN JSON VALUE
                               if V_JSON_VALOR is not null and V_JSON_VALOR.IS_STRING then
                                  g_cod_mon_factura := V_JSON_VALOR.GET_STRING; --SE OBTIENE EL VALOR
                               end if;
                            end if;

                         end if;
                      end;
                   elsif V_TAG = 'CABECERA' then
                      begin
                         V_JSON_CABECERA := V_JSON_DATA_OBJ.GET('CABECERA'); --SE CARGA EN JSON VALUE
                         if V_JSON_CABECERA.IS_OBJECT then
                            V_JSON_CABECERA_OBJ := TYP_JSON(V_JSON_CABECERA); --SE CARGA EN JSON OBJETO
                            for CAB in 1 .. V_JSON_CABECERA_OBJ.COUNT loop
                               V_JSON_VALOR := V_JSON_CABECERA_OBJ.JSON_DATA(CAB);
                               if V_JSON_VALOR.IS_OBJECT = false then
                                  V_CAMPO_MENSAJE := V_JSON_VALOR.MAPNAME;
                                  V_VALOR_AUX     := V_JSON_VALOR.GET_STRING;
                                  DBMS_OUTPUT.PUT_LINE(V_CAMPO_MENSAJE);
                                  
                                  --BUQUEDA DE CAMPO DINAMICO
                                  PR_CAM_DINAMICO(V_ARCHIVO,
                                                  V_TAG,
                                                  V_CAMPO_MENSAJE,
                                                  V_EXISTE,
                                                  V_NOM_TABLA,
                                                  V_CAMPO,
                                                  V_FUNCION,
                                                  V_FORMATO);
                                  PR_SENTENCIA_SQL(V_EXISTE,
                                                   V_CAMPO,
                                                   V_NOM_TABLA,
                                                   V_FORMATO,
                                                   V_VALOR_AUX,
                                                   V_COLUMNAS,
                                                   V_VALORES);

                               end if;
                            end loop;
                            V_SENTENCIA := V_COLUMNAS || V_VALORES || ')';
                            DBMS_OUTPUT.PUT_LINE(V_SENTENCIA);
                            V_SQL_CAB('CABECERA') := V_SENTENCIA;
                         end if;
                      end;
                      V_COLUMNAS := null;
                      V_VALORES  := null;
                   elsif V_TAG = 'DETALLE' then
                      V_JSON_DETALLE := V_JSON_DATA_OBJ.GET('DETALLE'); --SE CARGA EN JSON VALUE
                      if V_JSON_DETALLE.IS_OBJECT then
                         V_JSON_DETALLE_OBJ := TYP_JSON(V_JSON_DETALLE); --SE CARGA EN JSON OBJETO

                         V_JSON_OBJ := TYP_JSON(V_JSON_DETALLE);
                         for C in 1 .. V_JSON_OBJ.COUNT loop
                            V_JSON_VALOR    := V_JSON_DETALLE_OBJ.JSON_DATA(C);
                            V_CAMPO_MENSAJE := V_JSON_VALOR.MAPNAME;
                            DBMS_OUTPUT.PUT_LINE('-' || V_CAMPO_MENSAJE);

                            if V_JSON_VALOR.IS_OBJECT then
                               V_JSON_OBJ_NIV1 := TYP_JSON(V_JSON_VALOR);
                               for C1 in 1 .. V_JSON_OBJ_NIV1.COUNT loop
                                  V_JSON_VALOR    := V_JSON_OBJ_NIV1.JSON_DATA(C1);
                                  V_CAMPO_MENSAJE := V_JSON_VALOR.MAPNAME;
                                  DBMS_OUTPUT.PUT_LINE('--' || V_CAMPO_MENSAJE);

                                  if V_JSON_VALOR.IS_OBJECT then
                                     if V_CAMPO_MENSAJE = 'SUBDETALLE' then
                                        V_TAG := V_CAMPO_MENSAJE; --subdetalle
                                     end if;

                                     V_JSON_OBJ_NIV2 := TYP_JSON(V_JSON_VALOR);
                                     for C2 in 1 .. V_JSON_OBJ_NIV2.COUNT loop
                                        V_JSON_VALOR    := V_JSON_OBJ_NIV2.JSON_DATA(C2);
                                        V_CAMPO_MENSAJE := V_JSON_VALOR.MAPNAME;
                                        DBMS_OUTPUT.PUT_LINE('---' || V_CAMPO_MENSAJE);

                                        if V_JSON_VALOR.IS_OBJECT then
                                           V_JSON_OBJ_NIV3 := TYP_JSON(V_JSON_VALOR);
                                           for C3 in 1 .. V_JSON_OBJ_NIV3.COUNT loop
                                              V_JSON_VALOR    := V_JSON_OBJ_NIV3.JSON_DATA(C3);
                                              V_CAMPO_MENSAJE := V_JSON_VALOR.MAPNAME;
                                              DBMS_OUTPUT.PUT_LINE('----' || V_CAMPO_MENSAJE);
                                              if V_JSON_VALOR.IS_OBJECT = false then
                                                 V_VALOR_AUX := V_JSON_VALOR.GET_STRING;
                                                 PR_CAM_DINAMICO(V_ARCHIVO,
                                                                 V_TAG,
                                                                 V_CAMPO_MENSAJE,
                                                                 V_EXISTE,
                                                                 V_NOM_TABLA,
                                                                 V_CAMPO,
                                                                 V_FUNCION,
                                                                 V_FORMATO);
                                                 PR_SENTENCIA_SQL(V_EXISTE,
                                                                  V_CAMPO,
                                                                  V_NOM_TABLA,
                                                                  V_FORMATO,
                                                                  V_VALOR_AUX,
                                                                  V_COLUMNAS3,
                                                                  V_VALORES3);
                                              end if;
                                           end loop;
                                           if V_COLUMNAS3 is not null then
                                              V_SENTENCIA := V_COLUMNAS3 || V_VALORES3 || ')';
                                              DBMS_OUTPUT.PUT_LINE(V_SENTENCIA);
                                              V_COUNT_SQL := V_COUNT_SQL + 1;
                                              V_SQL_NIV_3('SUBDETALLE' || V_COUNT_SQL) := V_SENTENCIA;
                                              V_COLUMNAS3 := null;
                                              V_VALORES3 := null;
                                           end if;

                                        else
                                           V_VALOR_AUX := V_JSON_VALOR.GET_STRING;
                                           PR_CAM_DINAMICO(V_ARCHIVO,
                                                           V_TAG,
                                                           V_CAMPO_MENSAJE,
                                                           V_EXISTE,
                                                           V_NOM_TABLA,
                                                           V_CAMPO,
                                                           V_FUNCION,
                                                           V_FORMATO);
                                           PR_SENTENCIA_SQL(V_EXISTE,
                                                            V_CAMPO,
                                                            V_NOM_TABLA,
                                                            V_FORMATO,
                                                            V_VALOR_AUX,
                                                            V_COLUMNAS2,
                                                            V_VALORES2);
                                        end if;

                                     end loop;
                                     if V_COLUMNAS2 is not null then
                                        V_SENTENCIA := V_COLUMNAS2 || V_VALORES2 || ')';
                                        DBMS_OUTPUT.PUT_LINE(V_SENTENCIA);
                                        V_COUNT_SQL := V_COUNT_SQL + 1;
                                        V_SQL_NIV_2('DET_NIV2' || V_COUNT_SQL) := V_SENTENCIA;
                                        V_COLUMNAS2 := null;
                                        V_VALORES2 := null;
                                     end if;
                                  else
                                     V_VALOR_AUX := V_JSON_VALOR.GET_STRING;
                                     PR_CAM_DINAMICO(V_ARCHIVO,
                                                     V_TAG,
                                                     V_CAMPO_MENSAJE,
                                                     V_EXISTE,
                                                     V_NOM_TABLA,
                                                     V_CAMPO,
                                                     V_FUNCION,
                                                     V_FORMATO);
                                     PR_SENTENCIA_SQL(V_EXISTE,
                                                      V_CAMPO,
                                                      V_NOM_TABLA,
                                                      V_FORMATO,
                                                      V_VALOR_AUX,
                                                      V_COLUMNAS1,
                                                      V_VALORES1);
                                  end if;
                                  V_TAG := 'DETALLE';
                               end loop;
                               if V_COLUMNAS1 is not null then
                                  V_SENTENCIA := V_COLUMNAS1 || V_VALORES1 || ')';
                                  DBMS_OUTPUT.PUT_LINE(V_SENTENCIA);
                                  V_COUNT_SQL := V_COUNT_SQL + 1;
                                  V_SQL_NIV_1('DET_NIV1' || V_COUNT_SQL) := V_SENTENCIA;
                                  V_COLUMNAS1 := null;
                                  V_VALORES1 := null;
                               end if;
                            else
                               V_VALOR_AUX := V_JSON_VALOR.GET_STRING;
                               PR_CAM_DINAMICO(V_ARCHIVO,
                                               V_TAG,
                                               V_CAMPO_MENSAJE,
                                               V_EXISTE,
                                               V_NOM_TABLA,
                                               V_CAMPO,
                                               V_FUNCION,
                                               V_FORMATO);
                               PR_SENTENCIA_SQL(V_EXISTE,
                                                V_CAMPO,
                                                V_NOM_TABLA,
                                                V_FORMATO,
                                                V_VALOR_AUX,
                                                V_COLUMNAS,
                                                V_VALORES);
                            end if;
                         end loop;
                         if V_COLUMNAS is not null then
                            V_SENTENCIA := V_COLUMNAS || V_VALORES || ')';
                            DBMS_OUTPUT.PUT_LINE(V_SENTENCIA);
                            V_COUNT_SQL := V_COUNT_SQL + 1;
                            V_SQL_NIV_0('DET_NIV0' || V_COUNT_SQL) := V_SENTENCIA;
                            V_COLUMNAS := null;
                            V_VALORES := null;
                         end if;

                      end if;
                   end if;
                end loop;

                --EJECUCION DE LOS SQL

                declare
                  v_err_insert exception;
                begin
                   --CABECERA
                   begin
                      I     := V_SQL_CAB.FIRST;
                      V_SQL := V_SQL_CAB(I);
                      DBMS_OUTPUT.PUT_LINE('CAB - ' || V_SQL);
                      SQL_UTIL.EJECUTE_DML(V_SQL, V_ERROR);
                      if V_ERROR is not null then
                         P_COD_ERROR := '0028';
                         P_MENSAJE   := 'Error Insertando Registro ' || ' - ' ||
                                        replace(V_ERROR, 'SQL_UTIL.EJECUTE_CONSULTA', '');
                         raise v_err_insert;
                      end if;
                   end;
                   --DETALLE NIVEL 0
                   begin
                      I := V_SQL_NIV_0.FIRST;
                      while (I is not null) loop
                         V_SQL := V_SQL_NIV_0(I);
                         DBMS_OUTPUT.PUT_LINE('DET 0  - ' || V_SQL);
                         I := V_SQL_NIV_0.NEXT(I);
                         SQL_UTIL.EJECUTE_DML(V_SQL, V_ERROR);
                         if V_ERROR is not null then
                            P_COD_ERROR := '0028';
                            P_MENSAJE   := 'Error Insertando Registro ' || ' - ' ||
                                           replace(V_ERROR, 'SQL_UTIL.EJECUTE_CONSULTA', '');
                            raise v_err_insert;
                         end if;
                      end loop;
                   end;

                   --DETALLE NIVEL 1
                   begin
                      I := V_SQL_NIV_1.FIRST;
                      while (I is not null) loop
                         V_SQL := V_SQL_NIV_1(I);
                         DBMS_OUTPUT.PUT_LINE('DET 1  - ' || V_SQL);
                         I := V_SQL_NIV_1.NEXT(I);
                         SQL_UTIL.EJECUTE_DML(V_SQL, V_ERROR);
                         if V_ERROR is not null then
                            P_COD_ERROR := '0028';
                            P_MENSAJE   := 'Error Insertando Registro ' || ' - ' ||
                                           replace(V_ERROR, 'SQL_UTIL.EJECUTE_CONSULTA', '');
                            raise v_err_insert;
                         end if;
                      end loop;
                   end;

                   --DETALLE NIVEL 2
                   begin
                      I := V_SQL_NIV_2.FIRST;
                      while (I is not null) loop
                         V_SQL := V_SQL_NIV_2(I);
                         DBMS_OUTPUT.PUT_LINE('DET 2  - ' || V_SQL);
                         I := V_SQL_NIV_2.NEXT(I);
                         SQL_UTIL.EJECUTE_DML(V_SQL, V_ERROR);
                         if V_ERROR is not null then
                            P_COD_ERROR := '0028';
                            P_MENSAJE   := 'Error Insertando Registro ' || ' - ' ||
                                           replace(V_ERROR, 'SQL_UTIL.EJECUTE_CONSULTA', '');
                            raise v_err_insert;
                         end if;
                      end loop;
                   end;

                   --DETALLE NIVEL 3
                   begin
                      I := V_SQL_NIV_3.FIRST;
                      while (I is not null) loop
                         V_SQL := V_SQL_NIV_3(I);
                         DBMS_OUTPUT.PUT_LINE('DET 3  - ' || V_SQL);
                         I := V_SQL_NIV_3.NEXT(I);
                         SQL_UTIL.EJECUTE_DML(V_SQL, V_ERROR);
                         if V_ERROR is not null then
                            P_COD_ERROR := '0028';
                            P_MENSAJE   := 'Error Insertando Registro ' || ' - ' ||
                                           replace(V_ERROR, 'SQL_UTIL.EJECUTE_CONSULTA', '');
                            raise v_err_insert;
                         end if;

                      end loop;
                   end;

                   --UPDATES


                exception
                  when  v_err_insert then

                    rollback;
                end;

             end;
      END;

    BEGIN

      for c in datos loop
          v_jdatos0 := typ_json(c.dato);
          for i in 1 .. v_jdatos0.count loop
              v_vdato0 := v_jdatos0.get(i);
              v_jdatos1 := typ_json(v_vdato0);
              If upper(v_vdato0.mapname) = 'DATOS' Then
                  v_lugar := 'Tag DATOS';
                  g_archivo := 'LIMITES';
                      for x in 1..v_jdatos1.count Loop
                         v_jdatos2  := typ_json(v_jdatos1.json_data(x));
                         v_vdato1  := v_jdatos2.get(x);
                         if v_vdato1.is_string then -- Cliente
                            v_lugar := 'Tag CLIENTE';
                            For g in 1..v_jdatos2.count loop
                                If upper(v_jdatos2.json_data(g).mapname) = 'CODIGO' then
                                   v_cod_persona := v_jdatos2.json_data(g).str;
                                   Begin
                                        Select cod_persona
                                          into v_ver_persona
                                          from ba_personas a
                                         where a.cod_persona = v_cod_persona;
                                   Exception
                                        When no_data_found Then
                                             v_cod_error := '0020';
                                             v_mensaje   := 'Cliente Inexistente';
                                        When Others Then
                                             v_cod_error := '0999';
                                             v_mensaje   := 'Error al Buscar al Cliente - '||sqlerrm;
                                   End;
                                Elsif upper(v_jdatos2.json_data(g).mapname) = 'SOLICITUD' then
                                   v_nro_sol_crm := v_jdatos2.json_data(g).str;
                                Elsif upper(v_jdatos2.json_data(g).mapname) = 'URL' then
                                   P_URL := v_jdatos2.json_data(g).str;
                                Elsif upper(v_jdatos2.json_data(g).mapname) = 'GUIDMENSAJE' then
                                   v_guid_crm := v_jdatos2.json_data(g).str;
                                   P_GUID_CRM := v_guid_crm;
                                   g_guid_crm := v_guid_crm;
                                   
                                Elsif upper(v_jdatos2.json_data(g).mapname) = 'MODULO' then
                                   v_mod_crm := v_jdatos2.json_data(g).str;
                                Elsif upper(v_jdatos2.json_data(g).mapname) = 'USUSANCIONADOR' then
                                   P_COD_USU_SANCIONADOR := v_jdatos2.json_data(g).str;
                                   P_COD_USU_SANCIONADOR := substr(P_COD_USU_SANCIONADOR, 0, 10);
                                   Begin
                                        Select cod_usuario
                                          into v_ver_usuario
                                          from ba_usuarios a
                                         where a.cod_usuario = P_COD_USU_SANCIONADOR
                                           and a.estado      = 'A';
                                   Exception
                                        When no_data_found Then
                                             Begin
                                                 Select cod_usuario
                                                   into v_ver_usuario
                                                   from ba_usuarios a
                                                  where a.cod_usuario = P_COD_USU_SANCIONADOR;
                                             Exception
                                                 When no_data_found Then
                                                      v_cod_error := '0022';
                                                      v_mensaje   := 'Usuario Sancionador Inactivo en el Core';
                                                 When Others Then
                                                      v_cod_error := '0999';
                                                      v_mensaje   := 'Error al Buscar Estado del Usuario Sancionador - '||sqlerrm;
                                             End;
                                             v_cod_error := '0021';
                                             v_mensaje   := 'Usuario Sancionador Inexistente en el Core';
                                        When Others Then
                                             v_cod_error := '0999';
                                             v_mensaje   := 'Error al Buscar al Usuario Sancionador '||sqlerrm;
                                   End;
                                Elsif upper(v_jdatos2.json_data(g).mapname) = 'USUSOLICITANTE' then
                                   P_COD_USU_SOLICITANTE := v_jdatos2.json_data(g).str;
                                   P_COD_USU_SOLICITANTE := substr(P_COD_USU_SOLICITANTE, 0, 10);
                                   Begin
                                        Select cod_usuario
                                          into v_ver_usuario
                                          from ba_usuarios a
                                         where a.cod_usuario = P_COD_USU_SOLICITANTE
                                           and a.estado      = 'A';
                                   Exception
                                        When no_data_found Then
                                             Begin
                                                 Select cod_usuario
                                                   into v_ver_usuario
                                                   from ba_usuarios a
                                                  where a.cod_usuario = P_COD_USU_SOLICITANTE;
                                             Exception
                                                 When no_data_found Then
                                                      v_cod_error := '0024';
                                                      v_mensaje   := 'Usuario Solicitante Inactivo en el Core';
                                                 When Others Then
                                                      v_cod_error := '0999';
                                                      v_mensaje   := 'Error al Buscar Estado del Usuario Solicitante - '||sqlerrm;
                                             End;
                                             v_cod_error := '0023';
                                             v_mensaje   := 'Usuario Solicitante Inexistente en el Core';
                                        When Others Then
                                             v_cod_error := '0999';
                                             v_mensaje   := 'Error al Buscar al Usuario Solicitante '||sqlerrm;
                                   End;
                                End If;
                            End Loop;
                         ElsIf v_vdato1.is_array then -- Operacion
                            v_lugar := 'Tag OPERACION';
                            For l in 1..v_jdatos2.count Loop
                                 -- Identificacion del Tipo de Operacion
                                 If upper(v_jdatos2.json_data(l).mapname) = 'PUNTUALES' Then
                                    v_tip_operacion := 'P';
                                 ElsIf upper(v_jdatos2.json_data(l).mapname) = 'LIMITES' Then
                                    v_tip_operacion := 'L';
                                 End If;
                                 v_ldato0 := typ_jsonlist(v_jdatos2.json_data(l));
                                 v_jdatos3   := typ_json(v_ldato0);
                                 -- Recorrido de todos los productos
                                 If v_tip_operacion = 'P' Then -- Operacion Puntual
                                       v_lugar := 'Tag OPERACION PUNTUAL';
                                       For v in 1.. v_ldato0.count Loop
                                           v_jdatos4   := typ_json(v_jdatos3.json_data(v));
                                           v_vdato2  := v_jdatos2.get(v);
                                           -- Recorrido de Cada Producto
                                           For z in 1..v_jdatos4.count Loop
                                                   If v_jdatos4.json_data(z).is_object Then -- Object
                                                      v_jdatos5  := typ_json(v_jdatos4.json_data(z));
                                                      If upper(v_jdatos4.json_data(z).mapname) = 'PRODUCTO' Then
                                                          For m in 1..v_jdatos5.count loop
                                                              If upper(v_jdatos5.json_data(m).mapname) = 'MODULO' Then
                                                                 v_cod_modulo := v_jdatos5.json_data(m).str;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'MODALIDAD' Then
                                                                 v_cod_modalidad := v_jdatos5.json_data(m).str;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'MONEDA' Then
                                                                 v_cod_moneda := v_jdatos5.json_data(m).str;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'MONTO' Then
                                                                 v_monto := v_jdatos5.json_data(m).str;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'PLAZO' Then
                                                                 If nvl(v_jdatos5.json_data(m).str,0) = 0 Then
                                                                    v_plazo := 365;
                                                                 Else
                                                                    v_plazo := v_jdatos5.json_data(m).str;
                                                                 End If;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'CAMPANA' Then
                                                                 v_cod_campana := v_jdatos5.json_data(m).str;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'TIPO' Then
                                                                 If upper(v_jdatos5.json_data(m).str) = 'NUEVOS' Then
                                                                    v_tip_venta := 'N';
                                                                 ElsIf upper(v_jdatos5.json_data(m).str) = 'RENOVACION' Then
                                                                    v_tip_venta := 'R';
                                                                 ElsIf upper(v_jdatos5.json_data(m).str) = 'REFINANCIACION' Then
                                                                    v_tip_venta := 'F';
                                                                 ElsIf upper(v_jdatos5.json_data(m).str) = 'RESTRUCTURACION' Then
                                                                    v_tip_venta := 'E';
                                                                 End If;
                                                              End If;
                                                          End Loop;
                                                     Elsif upper(v_jdatos4.json_data(z).mapname) = 'GARANTIAS' Then
                                                          For m in 1..v_jdatos5.count loop
                                                              If upper(v_jdatos5.json_data(m).mapname) = 'TIPO' Then
                                                                  v_tip_garantia := F_OBT_GARANTIA(Upper(v_jdatos5.json_data(m).str));
                                                                  If v_tip_garantia = 0 Then
                                                                      v_cod_error := '0026';
                                                                      v_mensaje   := 'Garantia: '||Upper(v_jdatos5.json_data(m).str)|| 'Inexistente';
                                                                  End IF;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'GARANTE' Then
                                                                   v_cod_per_garante := v_jdatos5.json_data(m).str;
                                                              ElsIf upper(v_jdatos5.json_data(m).mapname) = 'MONTO' Then
                                                                   v_mto_gar_aplicado := to_number(v_jdatos5.json_data(m).str);
                                                              End If;
                                                          End Loop;
                                                     End If;
                                                   End If;
                                           End Loop;
                                           P_INS_DATOS(P_ID              ,
                                                       v_fecha           ,
                                                       v_hora            ,
                                                       v_nro_sol_crm     ,
                                                       v_cod_persona     ,
                                                       v_tip_operacion   ,
                                                       v_tip_venta       ,
                                                       v_cod_moneda      ,
                                                       v_monto           ,
                                                       v_plazo           ,
                                                       v_fecha           ,
                                                       v_tip_garantia    ,
                                                       v_cod_per_garante ,
                                                       v_mto_gar_aplicado,
                                                       v_cod_modulo      ,
                                                       v_cod_modalidad   ,
                                                       v_mto_sub         ,
                                                       v_cod_campana     ,
                                                       v_cod_oficina     ,
                                                       v_mod_crm         ,
                                                       V_COD_ERROR       ,
                                                       V_MENSAJE         );
                                       End Loop;
                                Elsif v_tip_operacion = 'L' Then-- Linea de Credito
                                     v_lugar := 'Tag LINEA DE CREDITO';
                                     For v in 1.. v_ldato0.count Loop
                                         v_jdatos4   := typ_json(v_jdatos3.json_data(v));
                                         v_vdato2  := v_jdatos2.get(v);
                                         -- Recorrido de Cada Producto
                                         For z in 1..v_jdatos4.count Loop
                                             If v_jdatos4.json_data(z).is_string Then --String:: Obtengo Valores de la Cabecera
                                                If upper(v_jdatos4.json_data(z).mapname) = 'C_MONTO' Then
                                                   v_monto := to_number(v_jdatos4.json_data(z).str);
                                                Elsif upper(v_jdatos4.json_data(z).mapname) = 'B_MONEDA' Then
                                                   v_cod_moneda := v_jdatos4.json_data(z).str;
                                                Elsif upper(v_jdatos4.json_data(z).mapname) = 'D_PLAZO' Then
                                                   If nvl(v_jdatos4.json_data(z).str,0) = 0 Then
                                                      v_plazo := 365;
                                                   Else
                                                      v_plazo := v_jdatos4.json_data(z).str;
                                                   End If;
                                                Elsif upper(v_jdatos4.json_data(z).mapname) = 'A_CAMPANA' Then
                                                   v_cod_campana := v_jdatos4.json_data(z).str;
                                                End If;
                                             Elsif v_jdatos4.json_data(z).is_array Then --Array:: Obtengo Garantias
                                                v_ldato1  := typ_jsonlist(v_jdatos4.json_data(z));
                                                For a in 1..v_ldato1.count Loop
                                                    v_vdato3 := v_ldato1.get(a);
                                                    v_jdatos5  := typ_json(v_vdato3);
                                                    For q in 1..v_jdatos5.count Loop
                                                        If v_jdatos5.json_data(q).is_string Then -- String
                                                           If Upper(v_jdatos5.json_data(q).mapname) = 'B_TIPO' Then
                                                              v_tip_garantia := F_OBT_GARANTIA(upper(v_jdatos5.json_data(q).str));
                                                           ElsIf Upper(v_jdatos5.json_data(q).mapname) = 'A_MONTO' Then
                                                              v_mto_gar_aplicado := to_number(v_jdatos5.json_data(q).str);
                                                           End If;
                                                        ElsIf v_jdatos5.json_data(q).is_array Then -- Array
                                                           v_ldato2  := typ_jsonlist(v_jdatos5.json_data(q));
                                                           v_jdatos6   := typ_json(v_ldato2);
                                                           For vx in 1..v_ldato2.count Loop
                                                               v_jdatos7   := typ_json(v_jdatos6.json_data(vx));
                                                               v_vdato4  := v_jdatos7.get(vx);
                                                               For sd in 1..v_jdatos7.count Loop -- String
                                                                   If upper(v_jdatos7.json_data(sd).mapname) = 'MODULO' Then
                                                                      v_cod_modulo := v_jdatos7.json_data(sd).str;
                                                                   ElsIf upper(v_jdatos7.json_data(sd).mapname) = 'MODALIDAD' Then
                                                                      v_cod_modalidad := v_jdatos7.json_data(sd).str;
                                                                   ElsIf upper(v_jdatos7.json_data(sd).mapname) = 'MONTO' Then
                                                                      v_mto_sub := v_jdatos7.json_data(sd).str;
                                                                   End If;
                                                               End Loop;
                                                               P_INS_DATOS(P_ID              ,
                                                                           v_fecha           ,
                                                                           v_hora            ,
                                                                           v_nro_sol_crm     ,
                                                                           v_cod_persona     ,
                                                                           v_tip_operacion   ,
                                                                           v_tip_venta       ,
                                                                           v_cod_moneda      ,
                                                                           v_monto           ,
                                                                           v_plazo           ,
                                                                           v_fecha           ,
                                                                           v_tip_garantia    ,
                                                                           v_cod_per_garante ,
                                                                           v_mto_gar_aplicado,
                                                                           v_cod_modulo      ,
                                                                           v_cod_modalidad   ,
                                                                           v_mto_sub         ,
                                                                           v_cod_campana     ,
                                                                           v_cod_oficina     ,
                                                                           v_mod_crm         ,
                                                                           V_COD_ERROR       ,
                                                                           V_MENSAJE         );
                                                           End Loop;
                                                        End If;
                                                    End Loop;
                                                End Loop;
                                             End IF;
                                         End Loop;
                                     End Loop;
                                End If; --> Tipo de Operacion
                            End Loop;
                        End If;
                      End Loop;
              ElsIf upper(v_vdato0.mapname) = 'CRM_RESP' Then
                    If v_vdato0.is_object Then -- Es Objeto; Viene las respuesta de creacion de Admisiones desde IT a CRM
                      -- 1) Buscar datos necesarios para optener el codigo de mensaje a actualizar
                      for x in 1..v_jdatos1.count Loop
                          If upper(v_jdatos1.json_data(x).mapname) = 'COD_PERSONA' Then
                             v_cod_persona   := v_jdatos1.json_data(x).str;
                          ElsIf upper(v_jdatos1.json_data(x).mapname) = 'NRO_SOLICITUD' Then
                             v_nro_sol_it    := v_jdatos1.json_data(x).str;
                          ElsIf upper(v_jdatos1.json_data(x).mapname) = 'COD_RESPUESTA' Then
                             v_cod_resp_crm  := v_jdatos1.json_data(x).str;
                          End If;
                      end loop;
                      -- 2) Optener el codigo de mensaje.
                      Begin
                          Select distinct(t.cod_mensaje)
                            into v_cod_mensaje
                            from ge_exp_aplicaciones_det t, ge_exp_aplicaciones_cab a
                           where t.cod_persona   = v_cod_persona
                             and a.cod_mensaje = t.cod_mensaje
                             and a.estado in ('P','E')
                             and a.det_error is null
                             and t.nro_solicitud = v_nro_sol_it;
                      Exception
                             When no_data_found then
                                  v_cod_error := '0026';
                                  v_mensaje   := 'No se encuentra codigo de mensaje a actualizar';
                      End;
                      -- 3) Actualizar Campos
                      If nvl(v_cod_error,'0000') = '0000' Then
                          For x in 1..v_jdatos1.count Loop
                              -- Buscar Configuracion dinamica de campos a actualizar
                              BEGIN
                                Select 'S'     , a.nom_tabla, a.campo
                                  into v_existe, v_nom_tabla, v_campo
                                  From ge_arc_campos a
                                 where a.referencia in ('REC_DAT_CRM')
                                   and a.descripcion = upper(v_jdatos1.json_data(x).mapname);
                              EXCEPTION
                                  When no_data_found then
                                       v_existe := 'N';
                                  When Others then
                                       v_cod_error := '0027';
                                       v_mensaje   := 'Error al buscar configuracion dinamica '||sqlerrm;
                              END;
                              -- Actualizar el mensaje
                              If nvl(v_cod_error,'0000') = '0000' and v_existe = 'S' Then
                                   -- ejecuta el select dinamicamente
                                   iF v_cod_resp_crm <> '0000' and v_campo = 'DET_ERROR' Then
                                      v_sentencia := 'Update '||v_nom_tabla||' set '||v_campo||' = '||chr(39)||v_jdatos1.json_data(x).str||chr(39)||' Where cod_mensaje = '||v_cod_mensaje;
                                      sql_util.ejecute_dml (v_sentencia,
                                                            v_error);
                                   ElsIf v_cod_resp_crm = '0000' and v_campo = 'DET_ERROR' Then
                                      null;
                                   Else
                                      v_sentencia := 'Update '||v_nom_tabla||' set '||v_campo||' = '||chr(39)||v_jdatos1.json_data(x).str||chr(39)||' Where cod_mensaje = '||v_cod_mensaje;
                                      sql_util.ejecute_dml (v_sentencia,
                                                            v_error);
                                   End If;
                                  /*sql_util.ejecute_dml (v_sentencia,
                                                        v_error);*/
                                  if v_error is not null then
                                     v_cod_error := '0028';
                                     v_mensaje   := 'Error Actualizando Registro '||' - '||replace(v_error,'SQL_UTIL.EJECUTE_CONSULTA','');
                                  end if;
                              End If;
                           End Loop;
                       End IF;
                    Else --> No es objeto, el formato es incorrecto.
                         v_cod_error := '0029';
                         v_mensaje   := 'Estructura Json Incorrecta';
                    End If;
              --- TAG DATA PARA JSON DINAMICO CON BUSQUEDA A GE_ARC_CAMPOS A PARTIR DEL TAG METADATA
              ELSIF upper(v_vdato0.mapname) = 'DATA' Then

                P_PRO_DAT_DINAMICOS(C.DATO, P_GUID_CRM, V_COD_ERROR, V_MENSAJE);
              End If;
          End Loop;
      End Loop;
    EXCEPTION
        When Others Then
              If sqlcode = -30625 Then
                       v_cod_error := '0025';
                       v_mensaje   := 'Estructura Json Incorrecta '||v_lugar;
              Else
                       v_cod_error := '0999';
                       v_mensaje   := 'Error al Procesar Cadena Json: '||v_lugar||' - '||sqlerrm;
              End If;
    END;
   -----
   BEGIN
      g_url_crm :=  null;
      g_archivo := null;
      g_guid_crm := null;
      g_cod_mon_factura := null;

      Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; End;
      BEGIN
         SELECT S_ID_COM_APLICACIONES.NEXTVAL
           INTO V_ID
           FROM DUAL;
      EXCEPTION
          WHEN OTHERS THEN
               V_ERROR     := SQLERRM;
               V_COD_ERROR := '0002';
               V_MENSAJE   := 'Error al optener el ID '||V_ERROR;
      END;
      If nvl(V_COD_ERROR,'0000') = '0000' Then
          BEGIN
              INSERT INTO GE_EXP_APLICACIONES_CAB(COD_MENSAJE,
                                                  FECHA,
                                                  HORA,
                                                  MENSAJE,
                                                  ESTADO,
                                                  TIP_TRANSFERENCIA)
                                           VALUES(V_ID,
                                                  P_FECHA,
                                                  P_HORA,
                                                  P_DATOS,
                                                  'R',
                                                  'R');
          V_MENSAJE := 'Insercion de Cabecera Satisfactoria';
          EXCEPTION
                WHEN OTHERS THEN
                     V_ERROR     := SQLERRM;
                     V_COD_ERROR := '0003';
                     V_MENSAJE   := 'Error al Insertar la Cabecera - '||V_ERROR;
          END;
          commit;
      End If;
      If nvl(V_COD_ERROR,'0000') = '0000' Then
         PR_INS_DETALLE (V_ID                 ,
                         V_URL                ,
                         V_GUID_CRM           ,
                         V_COD_USU_SOLICITANTE,
                         V_COD_USU_SANCIONADOR,
                         V_COD_ERROR          ,
                         V_MENSAJE);
         If nvl(V_COD_ERROR,'0000') = '0000' Then
            COMMIT;
         End If;
      End If;
   END PR_INS_MENSAJE;
   -- Procedimiento para obtener datos del CRM
   PROCEDURE pr_obt_dat_crm(p_cod_persona   IN pr_solicitudes.cod_persona%TYPE,
                            p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                            p_cod_modulo    IN pr_solicitudes.cod_modulo%TYPE,
                            p_cod_modalidad IN pr_solicitudes.cod_modalidad%TYPE,
                            p_nro_sol_crm   OUT  ge_exp_aplicaciones_det.nro_sol_crm%TYPE,
                            p_est_crm       OUT ba_cod_referencias.abreviatura%TYPE,
                            p_url_crm       OUT ge_exp_aplicaciones_cab.url_crm%TYPE) IS

     v_hab_crm     VARCHAR2(1) := 'N';
     v_nro_sol_crm ge_exp_aplicaciones_det.nro_sol_crm%TYPE;
     v_est_crm     ge_exp_aplicaciones_det.est_sol_crm%TYPE;
     --v_des_est_crm ba_cod_referencias.abreviatura%TYPE;
     v_url_crm     ge_exp_aplicaciones_cab.url_crm%TYPE;

   BEGIN
     v_hab_crm := nvl(fug_obt_pardinamico('COD_MAD_PRE_CRM',p_cod_modulo,p_cod_modalidad),'N');
     IF v_hab_crm = 'S' THEN
       BEGIN
         SELECT b.nro_sol_crm, b.est_sol_crm, a.url_crm
           INTO v_nro_sol_crm, v_est_crm, v_url_crm
           FROM ge_exp_aplicaciones_cab a, ge_exp_aplicaciones_det b
          WHERE a.cod_mensaje = b.cod_mensaje
            AND b.nro_solicitud = p_nro_solicitud
            AND a.estado = 'P'
            AND b.cod_persona = p_cod_persona;
       EXCEPTION
         WHEN no_data_found THEN
           NULL;
       END;
       p_nro_sol_crm := v_nro_sol_crm;
       p_est_crm     := v_est_crm;
       p_url_crm     := v_url_crm;
     END IF;
   EXCEPTION
     WHEN no_data_found THEN
       NULL;
   END;
   -- Procedimiento para insertar en la tabla ge_exp_aplicaciones_cab
   PROCEDURE pr_ins_ge_exp_app_cab(rp_ge_exp_app_cab IN ge_exp_aplicaciones_cab%ROWTYPE) IS

   BEGIN
     INSERT INTO ge_exp_aplicaciones_cab
       (cod_mensaje, fecha, hora, mensaje,
        respuesta, estado, url_crm, guid_crm,
        cod_usu_solicitante, cod_usu_sancionador, det_error,
        tip_transferencia)
     VALUES
       (rp_ge_exp_app_cab.cod_mensaje, rp_ge_exp_app_cab.fecha, rp_ge_exp_app_cab.hora, rp_ge_exp_app_cab.mensaje,
        rp_ge_exp_app_cab.respuesta, rp_ge_exp_app_cab.estado, rp_ge_exp_app_cab.url_crm, rp_ge_exp_app_cab.guid_crm,
        substr(rp_ge_exp_app_cab.cod_usu_solicitante, 0, 10), substr(rp_ge_exp_app_cab.cod_usu_sancionador, 0, 10), rp_ge_exp_app_cab.det_error,
        rp_ge_exp_app_cab.tip_transferencia);
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20001, 'Error al insertar datos en la cabecera.'||SQLERRM);
   END;
   -- Procedimiento para insertar en la tabla ge_exp_aplicaciones_cab
   PROCEDURE pr_ins_ge_exp_app_det(rp_ge_exp_app_det IN ge_exp_aplicaciones_det%ROWTYPE) IS

   BEGIN
     INSERT INTO ge_exp_aplicaciones_det
       (cod_mensaje, fecha, hora, nro_sol_crm,
        guid_crm, nro_solicitud, cod_persona, tip_operacion,
        tip_venta, cod_moneda, mto_producto, plazo,
        fec_aprobacion, tip_garantia, cod_per_garante, mto_gar_aplicado,
        cod_modulo, cod_modalidad, mto_sub_producto, cod_campana,
        cod_oficina, est_sol_crm)
     VALUES
       (rp_ge_exp_app_det.cod_mensaje,rp_ge_exp_app_det.fecha,rp_ge_exp_app_det.hora,rp_ge_exp_app_det.nro_sol_crm,
        rp_ge_exp_app_det.guid_crm,rp_ge_exp_app_det.nro_solicitud,rp_ge_exp_app_det.cod_persona,rp_ge_exp_app_det.tip_operacion,
        rp_ge_exp_app_det.tip_venta,rp_ge_exp_app_det.cod_moneda,rp_ge_exp_app_det.mto_producto,rp_ge_exp_app_det.plazo,
        rp_ge_exp_app_det.fec_aprobacion,rp_ge_exp_app_det.tip_garantia,rp_ge_exp_app_det.cod_per_garante,rp_ge_exp_app_det.mto_gar_aplicado,
        rp_ge_exp_app_det.cod_modulo,rp_ge_exp_app_det.cod_modalidad,rp_ge_exp_app_det.mto_sub_producto,rp_ge_exp_app_det.cod_campana,
        rp_ge_exp_app_det.cod_oficina,rp_ge_exp_app_det.est_sol_crm);
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20001, 'Error al insertar datos en el detalle.'||SQLERRM);
   END;
   --
   PROCEDURE lp_reg_mensaje(p_mensaje IN LONG, p_respuesta IN VARCHAR2) is
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_respuesta ba_log_mensajeria.respuesta%type;
    BEGIN
       v_respuesta := substr(p_respuesta, 1, 4000);
       insert into ba_log_mensajeria
          (mensaje, respuesta)
       values
          (p_mensaje, v_respuesta);
       commit;
    EXCEPTION
       WHEN OTHERS THEN
          null;
    END;
   -- Procedimiento para generar JSON dicamicamente
   PROCEDURE pr_gen_json(p_destino     IN VARCHAR2,
                         p_referencia  IN VARCHAR2,
                         p_nro_sol_it  IN VARCHAR2,
                         p_json        OUT CLOB) IS

     v_app_destino   VARCHAR2(100) := p_destino;
     v_referencia    VARCHAR2(100) := p_referencia;
     v_nro_sol_it    VARCHAR2(100) := p_nro_sol_it;
     v_json          CLOB := '{';
     v_tag           VARCHAR2(100);
     v_sentencia     VARCHAR2(4000);
     v_msj           VARCHAR2(400);
     v_ref_cursor    sql_util.t_cursor_tab;
     v_filas         NUMBER;
     v_error         VARCHAR2(4000);
     v_val_parametro VARCHAR2(4000);
     v_registro      ROWID;
     v_aux           NUMBER := 0;
     v_rec           NUMBER := 0;
     v_rownun        NUMBER := 0;
     v_canrep        NUMBER := 0;
     v_id_campo      VARCHAR2(500);
     v_lugar         VARCHAR2(500);
     v_repetible     VARCHAR2(1);

     CURSOR c_estructura (p_referencia IN VARCHAR2) IS
       SELECT a.nro_secuencia, a.archivo mod_destino, a.campo, a.tip_dato tag, a.longitud tip_dato, a.funcion Valor, a.formato, a.saltar repetible, a.descripcion cam_tecnico
         FROM ge_arc_campos a, ge_arc_tablas b
        WHERE p_referencia IN (a.referencia,a.descripcion)
          AND a.referencia  = b.referencia   (+)
          AND a.pos_inicial = b.nro_secuencia(+)
        ORDER BY a.nro_secuencia;

     CURSOR c_dat_repetidos (p_referencia IN VARCHAR2) IS
       SELECT a.nro_secuencia, a.archivo mod_destino, a.campo, a.tip_dato tag, a.longitud tip_dato, a.funcion Valor, a.formato, a.saltar repetible, a.descripcion cam_tecnico,count(*) over () tot_rows
         FROM ge_arc_campos a, ge_arc_tablas b
        WHERE p_referencia in (a.referencia,a.tip_dato)
          AND a.referencia  = b.referencia   (+)
          AND a.pos_inicial = b.nro_secuencia(+)
        ORDER BY a.nro_secuencia;

     CURSOR c_garantias (p_nro_solicitud IN NUMBER, p_nro_registro IN NUMBER) IS
       SELECT cod_garantia, nro_garantia, pag_con.fu_for_monto(monto,cod_moneda) monto, rd, ri
         FROM (SELECT A.NRO_SOLICITUD, A.COD_GARANTIA, A.NRO_GARANTIA,
                      a.mto_aplicado monto, c.cod_moneda,
                      b.pri_aplicacion, rownum rd, a.rowid ri
                 FROM pr_sol_garantias a, pr_gar_tipos b, pr_solicitudes c
                WHERE a.cod_garantia  = b.cod_garantia
                  AND a.nro_solicitud = c.nro_solicitud
                  AND c.nro_solicitud = p_nro_solicitud)
        WHERE rd = NVL(p_nro_registro,rd)
        ORDER BY pri_aplicacion, monto;

     FUNCTION F_Json (p_json      IN CLOB,
                      p_tip_dato  IN VARCHAR2,
                      p_tag       IN VARCHAR2,
                      p_etiqueta  IN VARCHAR2,
                      p_campo     IN VARCHAR2,
                      p_parametro IN VARCHAR2) RETURN CLOB IS
       v_ref_cursorr  sql_util.t_cursor_tab;
       v_json         CLOB := p_json;
       v_campo        VARCHAR2(500);
       FUNCTION F_tip_Persona (p_valor    IN VARCHAR2,
                               p_etiqueta IN VARCHAR2,
                               p_campo    IN VARCHAR2) RETURN VARCHAR2 IS
         v_id_campo varchar2(500);
       BEGIN
         IF p_etiqueta = 'ID_PERSONA' AND upper(p_valor) like '%CONTACTS%' THEN
            v_id_campo := 'bbvapy_Cliente_contact'||p_campo;
         ELSIF p_etiqueta = 'ID_PERSONA' AND upper(p_valor) like '%ACCOUNTS%' THEN
            v_id_campo := 'bbvapy_Cliente_account'||p_campo;
         ELSE
            v_id_campo := p_campo;
         END IF;
            RETURN v_id_campo;
        END F_tip_Persona;
     BEGIN
       IF p_tip_dato = 0 THEN --> Dato en Duro Definido en el Parametro
         v_json := p_json||chr(34)|| p_campo ||chr(34) ||chr(58)|| chr(34)|| p_parametro ||chr(34);
       ELSIF p_tip_dato = 1 THEN --> Sentencia Sql dependiente de un Parametro
         sql_util.ejecute_consulta(p_parametro,
                                   1,
                                   v_filas,
                                   v_ref_cursorr,
                                   v_error);
         IF v_error IS NULL THEN
            v_campo := F_tip_Persona(P_PARAMETRO,P_ETIQUETA,P_CAMPO); 
            IF v_filas > 0 THEN
               v_json := p_json||chr(34)||v_campo||chr(34)||chr(58)||chr(34)||  v_ref_cursorr(1).columna1  ||chr(34);
            ELSE
              v_json := p_json||chr(34)||v_campo||chr(34)||chr(58)||chr(34) ||chr(34); 
            END IF;   
         ELSE
            raise_application_error(-20000,'Error en Secuencia 00 '||p_campo||' - '||REPLACE(v_error,'SQL_UTIL.EJECUTE_CONSULTA',''));
         END IF;
       ELSIF  p_tip_dato = 2 THEN --> Sentencia Sql NO Dependiente de un Parametro
         sql_util.ejecute_consulta(p_parametro,
                                   1,
                                   v_filas,
                                   v_ref_cursorr,
                                   v_error);
         IF v_error IS NULL THEN
            v_campo := F_tip_Persona(p_parametro,p_etiqueta,p_campo);  
            IF v_filas > 0 THEN
               v_json := p_json||chr(34)||v_campo||chr(34)||chr(58)||chr(34)||  v_ref_cursorr(1).columna1  ||chr(34);
            ELSE
              v_json := p_json||chr(34)||v_campo||chr(34)||chr(58)||chr(34) ||chr(34); 
            END IF;   
         ELSE
           raise_application_error(-20000,'Error en Secuencia 01 '||p_campo||' - '||REPLACE(v_error,'SQL_UTIL.EJECUTE_CONSULTA',''));
         END IF;
       END IF;
       RETURN v_json;
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000,'Error al Obtener Datos para '||p_campo||' - '||SQLERRM);
     END F_Json;

   BEGIN
     v_tag  := NULL;
     v_aux  := 0;
     v_rec  := 0;
     v_json := v_json||chr(34)||v_app_destino||chr(34)||chr(58)||'{';
     v_lugar := '01 antes del for';
     v_repetible := 'N';

     FOR x IN c_estructura (v_referencia) LOOP
       v_aux  := 0;
       v_lugar := '02 entro for';
       IF nvl(x.repetible,'N') = 'S' THEN
         LOOP
           v_aux  := 0;
           v_repetible := 'S';
           FOR g IN c_garantias (to_number(v_nro_sol_it), NULL) LOOP
             v_lugar := '03 entro for';
             IF v_aux = v_rec THEN
               v_rownun := g.rd;
             END IF;
             v_aux := v_aux + 1;
           END LOOP;

           v_rec := v_rec + 1;
           v_lugar := '04 antes for';
           FOR g IN c_dat_repetidos (x.tag) LOOP
             v_lugar := '05 entro for';
             FOR t IN c_garantias(to_number(v_nro_sol_it), v_rownun)  LOOP
               v_lugar := '06 entro for';
               BEGIN --> Buscar Parametros
                 SELECT CASE WHEN X.TIP_DATO IN (0,2) THEN
                                (SELECT CASE WHEN g.CAMPO = 'COD_GARANTIA' THEN
                                                  to_char(t.cod_garantia)
                                             WHEN g.campo = 'NRO_GARANTIA' THEN
                                                  to_char(t.NRO_GARANTIA)
                                             WHEN G.CAMPO = 'MONTO' THEN
                                                  to_char(t.MONTO)
                                        END
                                   FROM DUAL)
                             WHEN X.TIP_DATO = 1 THEN
                                (SELECT CASE WHEN g.CAMPO = 'COD_GARANTIA' THEN
                                                  g.VALOR||t.cod_garantia
                                             WHEN g.CAMPO IN ('NRO_GARANTIA','TIP_PER_GARANTE','TIP_DOC_GARANTIA','NRO_DOC_GARANTIA','NOM_GARANTIA') THEN --> Nro. Cliente para Codeudores.
                                                  g.VALOR||chr(39)||t.ri||chr(39)
                                             WHEN g.campo = 'MONTO' THEN
                                                  to_char(t.MONTO)
                                        END
                                   FROM DUAL)
                        END
                   INTO v_val_parametro
                   FROM dual;
                 EXCEPTION
                   WHEN OTHERS THEN
                     raise_application_error(-20000, 'Error al definir valores de parametros'||': '||SQLERRM);
                 END;
             END LOOP;
             IF nvl(v_tag,g.tag) <> g.tag THEN
               v_tag  := g.tag;
               v_json := v_json||'},';
               v_json := v_json||chr(34)||g.tag||chr(34)||chr(58)||'[{';
               --v_json := F_Json(v_json, g.tip_dato, v_tag, g.campo,  v_val_parametro);
               v_lugar := '07 if';
               v_json := F_Json(v_json, g.tip_dato, v_tag, g.campo, g.cam_tecnico,  v_val_parametro);
             ELSIF v_tag = g.tag THEN
               IF c_dat_repetidos%ROWCOUNT = 1 AND v_rec > 1 THEN
                 v_json := v_json||chr(44)||'{';
               ELSE
                 v_json := v_json||chr(44);
               END IF;
               v_lugar := '08 if';
               v_json := F_Json(v_json, g.tip_dato, v_tag, g.campo, g.cam_tecnico,  v_val_parametro);
             ELSIF v_tag IS NULL THEN
               v_lugar := '09 if';
               v_tag  := g.tag;
               v_json := v_json||chr(34)||g.tag||chr(34)||chr(58)||'[{';
               v_json := F_Json(v_json, g.tip_dato, v_tag, g.campo, g.cam_tecnico,  V_VAL_PARAMETRO);
             END IF;
           END LOOP;
           v_json := v_json||'}';
           IF v_rec = v_aux THEN
             v_json := v_json||']';
             EXIT;
           END IF;
         END LOOP;
         EXIT;
       ELSE
         v_lugar := '10 else';
         BEGIN --> Buscar Parametros
           SELECT CASE WHEN x.tip_dato IN (0,2) THEN
                            x.valor
                       WHEN x.tip_dato = 1 THEN
                            x.valor||v_nro_sol_it
                  END
             INTO v_val_parametro
             FROM dual;
         EXCEPTION
           WHEN OTHERS THEN
             raise_application_error(-20000, 'Error al definir valores de parametros'||': '||SQLERRM);
         END;
         v_lugar := '11 else';
         IF nvl(v_tag,x.tag) <> x.tag THEN
           v_tag  := x.tag;
           v_aux  := 0;
           v_json := v_json||'},';
           v_json := v_json||chr(34)||x.tag||chr(34)||chr(58)||'{';
           v_lugar := '12 if';
           v_json := F_Json(v_json, x.tip_dato, v_tag, x.campo, x.cam_tecnico,  v_val_parametro);
         ELSIF v_tag = x.tag THEN
           v_json := v_json||chr(44);
           v_lugar := '13 if';
           v_json := F_Json(v_json, x.tip_dato, v_tag, x.campo, x.cam_tecnico,  v_val_parametro);
         ELSIF v_tag IS NULL THEN
           v_tag  := x.tag;
           v_json := v_json||chr(34)||x.tag||chr(34)||chr(58)||'{';
           v_lugar := '14 if';
           v_json := F_Json(v_json, x.tip_dato, v_tag, x.campo, x.cam_tecnico,  v_val_parametro);
         END IF;
         v_repetible := 'N';
       END IF;
     END LOOP;
     v_lugar := '15 final';
     IF v_repetible = 'S' THEN
        v_json := v_json||'}}';
     ELSE
        v_json := v_json||'}}}';
     END IF;
     p_json := v_json;
     --v_lugar := dbms_lob.getlength(p_json);
     --dbms_output.put_line(v_lugar);
     lp_reg_mensaje(NULL, p_json);
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20020, 'Lugar: '||v_lugar||SQLERRM);
   END;
   --
   PROCEDURE pr_env_json(p_nro_solicitud  IN VARCHAR2,
                         p_cod_persona    IN VARCHAR2,
                         p_referencia in varchar2 default 'ENV_DAT_CRM') IS
     v_json          CLOB;
     v_destino       VARCHAR2(20) := 'CRM';
     v_referencia    VARCHAR2(20) := p_referencia;--'ENV_DAT_CRM';
     v_existe        VARCHAR2(2)  := 'N';
     v_nro_sol       VARCHAR2(20);
     rg_cab          ge_exp_aplicaciones_cab%ROWTYPE;
     rg_det          ge_exp_aplicaciones_det%ROWTYPE;
     v_fecha         DATE := pag_cal.FU_OBT_FEC_ACTUAL(6);
     v_hora          VARCHAR2(8) := TO_CHAR(SYSDATE,'HH24:MI:SS');
     v_err_code      NUMBER := 0;
     v_tot_prestamo  pr_solicitudes.tot_prestamo%TYPE;
     v_cod_moneda    pr_solicitudes.cod_moneda%TYPE;
     v_dia_plazo     pr_solicitudes.dia_plazo%TYPE;
     v_cod_modulo    pr_solicitudes.cod_modulo%TYPE;
     v_cod_modalidad pr_solicitudes.cod_modalidad%TYPE;
     v_cod_campana   pr_solicitudes.cod_campana%TYPE;
     v_cod_oficina   pr_solicitudes.cod_oficina%TYPE;
     v_url           ge_par_dinamicos.val_parametro%TYPE;
     v_ws_respuesta  paw_json.JSONStructObj;
     v_resPost       TYP_POSTRESPUESTA;
     v_respuesta     ge_exp_aplicaciones_cab.respuesta%TYPE;
     v_return        VARCHAR(10);

     CURSOR c_garantias IS
       SELECT a.nro_garantia, a.cod_garantia, a.mto_aplicado
         FROM pr_sol_garantias a
        WHERE a.nro_solicitud = p_nro_solicitud;

   BEGIN

     If v_referencia = 'ENV_DAT_CRM' Then
       BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ge_exp_aplicaciones_cab a, ge_exp_aplicaciones_det b
          WHERE a.cod_mensaje = b.cod_mensaje
            AND b.nro_solicitud = p_nro_solicitud
            AND b.cod_persona = p_cod_persona
            AND NVL(a.estado,'E') = 'P'
            AND a.tip_transferencia = 'E';
       EXCEPTION
         WHEN no_data_found THEN
           v_existe := 'N';
         WHEN too_many_rows THEN
           v_existe := 'S';
       END;
     end if;

     IF v_existe = 'S' THEN
       raise_application_error(-20001, 'La solicitud ya fue enviada. ');
       v_err_code := 1;
     END IF;
     v_nro_sol := to_char(p_nro_solicitud);
     -- Generar JSON
     BEGIN
       pag_con.pr_gen_json(v_destino,v_referencia,v_nro_sol,v_json);
     EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20002, 'Error al generar JSON. ');
       v_err_code := 2;
     END;

     -- Buscar datos de la solicitud
     If v_referencia = 'ENV_DAT_CRM' Then
       BEGIN
         SELECT a.tot_prestamo,a.cod_moneda,a.dia_plazo,a.cod_modulo,a.cod_modalidad,a.cod_campana,a.cod_oficina
           INTO v_tot_prestamo,v_cod_moneda,v_dia_plazo,v_cod_modulo,v_cod_modalidad,v_cod_campana,v_cod_oficina
           FROM pr_solicitudes a
          WHERE a.nro_solicitud = v_nro_sol
            AND a.cod_persona = p_cod_persona;
       EXCEPTION
         WHEN no_data_found THEN
         raise_application_error(-20003, 'Error al obtener datos de la solicitud. ');
         v_err_code := 3;
         WHEN OTHERS THEN
         raise_application_error(-20004, 'Error al obtener datos de la solicitud. ');
         v_err_code := 4;
       END;
     end if;

     -- Envio web service --
     BEGIN
       v_url        := fug_obt_pardinamico('CRM_PRE_CARGA', NULL, NULL);--http://62.12.240.13:9080/crmConnector/
       v_resPost    := fu_env_post(p_parametros => v_json, p_url => v_url);
       v_respuesta  := substr(v_resPost.respuesta,1,4000);
       IF (v_resPost.error = 'N') THEN
         v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
         v_return       := paw_json.getAttrValue(v_ws_respuesta, 'cod_respuesta');
       ELSE
         v_return       := paw_json.getAttrValue(v_ws_respuesta, 'cod_respuesta');
         v_err_code     := 5;
         raise_application_error(-20005, 'Error en el envio Web service. ');
       END IF;
     EXCEPTION
       WHEN OTHERS THEN
         v_return := '99';
     END;
     IF v_return = '0000' THEN -- OK envio web service
       -- Insert en ge_exp_aplicaciones_cab y ge_exp_aplicaciones_det
       SELECT s_id_com_aplicaciones.NEXTVAL
         INTO rg_cab.cod_mensaje
         FROM dual;

       -- Cabecera
       rg_cab.fecha              := v_fecha;
       rg_cab.hora               := v_hora;
       rg_cab.mensaje            := v_json;
       rg_cab.respuesta          := 'Procesando';--v_respuesta;
       rg_cab.estado             := 'P'; -- Procesado
       rg_cab.tip_transferencia  := 'E'; -- Enviado de IT
       pag_con.pr_ins_ge_exp_app_cab(rg_cab);
       -- Detalle

       If v_referencia = 'ENV_DAT_CRM' Then
         FOR i IN c_garantias LOOP
           rg_det.cod_mensaje      := rg_cab.cod_mensaje;
           rg_det.fecha            := v_fecha;
           rg_det.hora             := v_hora;
           rg_det.nro_solicitud    := p_nro_solicitud;
           rg_det.cod_persona      := p_cod_persona;
           rg_det.tip_operacion    := 'P'; -- Puntual
           rg_det.cod_moneda       := v_cod_moneda;
           rg_det.mto_producto     := v_tot_prestamo;
           rg_det.plazo            := v_dia_plazo;
           rg_det.tip_garantia     := i.cod_garantia;
           rg_det.cod_per_garante  := i.nro_garantia;
           rg_det.mto_gar_aplicado := i.mto_aplicado;
           rg_det.cod_modulo       := v_cod_modulo;
           rg_det.cod_modalidad    := v_cod_modalidad;
           rg_det.cod_campana      := v_cod_campana;
           rg_det.cod_oficina      := v_cod_oficina;

           pag_con.pr_ins_ge_exp_app_det(rg_det);
         END LOOP;
       ELSE
         rg_det.cod_mensaje      := rg_cab.cod_mensaje;
           rg_det.fecha            := v_fecha;
           rg_det.hora             := v_hora;
           rg_det.nro_solicitud    := p_nro_solicitud;
           rg_det.cod_persona      := p_cod_persona;
           --rg_det.tip_operacion    := 'P'; -- Puntual
           --rg_det.cod_moneda       := v_cod_moneda;
           --rg_det.mto_producto     := v_tot_prestamo;
           --rg_det.plazo            := v_dia_plazo;
           --rg_det.tip_garantia     := i.cod_garantia;
           --rg_det.cod_per_garante  := i.nro_garantia;
           --rg_det.mto_gar_aplicado := i.mto_aplicado;
           --rg_det.cod_modulo       := v_cod_modulo;
           --rg_det.cod_modalidad    := v_cod_modalidad;
           --rg_det.cod_campana      := v_cod_campana;
           --rg_det.cod_oficina      := v_cod_oficina;

           pag_con.pr_ins_ge_exp_app_det(rg_det);
       END IF;

       -- Todo OK commitear
       IF v_err_code = 0 THEN
         COMMIT;
       END IF;
     ELSE -- Retorno error el web service
       v_err_code     := 6;
       raise_application_error(-20005, 'Error en el envio Web service. ');
     END IF;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20006, 'Error al enviar solicitud al CRM. '||SQLERRM);
   END;
   --
   FUNCTION fu_env_post(p_parametros IN VARCHAR2,
                        p_url        IN VARCHAR2,
                        p_metodo     IN VARCHAR2 DEFAULT 'POST') RETURN TYP_POSTRESPUESTA IS
     v_retorno    VARCHAR2(32760) := '';
     v_buffer     VARCHAR2(32760) := '';
     v_req        UTL_HTTP.REQ;
     v_resp       UTL_HTTP.RESP;
     v_respuesta  TYP_POSTRESPUESTA:= TYP_POSTRESPUESTA();
     v_code       VARCHAR2(1) := NULL;
     v_parametros VARCHAR2(3000);
  BEGIN
     UTL_HTTP.set_transfer_timeout(160);
     BEGIN
        IF p_metodo = 'POST' THEN
           v_req       := UTL_HTTP.BEGIN_REQUEST(url => p_url, method => 'POST', http_version => 'HTTP/1.1');
           UTL_HTTP.SET_HEADER(r => v_req, NAME => 'Content-Type', VALUE => 'text/plain');--x-www-form-urlencoded;charset=utf-8
           UTL_HTTP.SET_HEADER(r => v_req, NAME => 'Content-Length', VALUE => length(p_parametros));
           UTL_HTTP.WRITE_TEXT(r => v_req, data => p_parametros);
        ELSIF p_metodo = 'GET' THEN
           SELECT nvl2(p_parametros, '?', '') INTO v_code FROM dual;
           v_parametros := p_url||v_code||p_parametros;
           v_req       := UTL_HTTP.BEGIN_REQUEST(v_parametros, 'GET', 'HTTP/1.1');
        END IF;
        v_resp                  := UTL_HTTP.GET_RESPONSE(r => v_req);
        v_respuesta.status_code := v_resp.status_code;
        v_respuesta.respuesta   := '';
        v_respuesta.error       := 'S';
        BEGIN
           LOOP
              UTL_HTTP.read_text(v_resp, v_buffer, 10000);
              v_retorno := v_retorno || v_buffer;
           END LOOP;
           UTL_HTTP.end_response(v_resp);
           v_respuesta.codigoError := 0;
           v_respuesta.respuesta   := v_retorno;
           v_respuesta.error       := 'N';
        EXCEPTION
           WHEN UTL_HTTP.end_of_body THEN -- 99% de las veces siempre va a salir porque leyo de mas
           v_respuesta.codigoError := 0;
           v_respuesta.respuesta   := v_retorno;
           v_respuesta.error       := 'N';
           UTL_HTTP.end_response(v_resp);
        END;
     EXCEPTION
        WHEN utl_tcp.network_error THEN
           UTL_HTTP.end_response(v_resp);
           v_respuesta.error                := 'S';
           v_respuesta.codigoError          := 1;
           v_respuesta.descripcionRespuesta := 'No hay conexion con el Servidor';
        WHEN utl_tcp.transfer_timeout THEN
           UTL_HTTP.end_response(v_resp);
           v_respuesta.error                := 'S';
           v_respuesta.codigoError          := 2;
           v_respuesta.descripcionRespuesta := 'Limite de tiempo de espera';
        WHEN OTHERS THEN
           BEGIN
              UTL_HTTP.end_response(v_resp);
           EXCEPTION
              WHEN OTHERS THEN
                 NULL;
           END;
           v_respuesta.error                := 'S';
           v_respuesta.descripcionRespuesta := substr(SQLERRM, 0, 200);
     END;
     RETURN(v_respuesta);
  END;
  --
  FUNCTION fu_for_monto(p_monto      IN NUMBER,
                        p_cod_moneda IN VARCHAR2) RETURN VARCHAR2 IS
    v_monto VARCHAR2(20);
  BEGIN
    SELECT DECODE(p_cod_moneda,'GS',
                  to_char(p_monto, '999,999,999,999'), -- Guaranies
                  to_char(p_monto, '999,999,999,999.99')) -- Otras monedas
      INTO v_monto
      FROM dual;
    RETURN TRIM(v_monto);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al formatear monto de solicitud. '||SQLERRM);
  END;

  FUNCTION fu_obt_cod_mon_pago(p_cod_ent_proveedor      IN NUMBER) RETURN VARCHAR2 IS
    v_cod_mon_pago VARCHAR2(20);
    v_nro_cta_proveedor varchar(15);

  BEGIN
   v_nro_cta_proveedor := fug_obt_parentes(p_cod_ent_proveedor, 'NRO_CTA_PPROV');
   IF v_nro_cta_proveedor IS NOT NULL THEN
      SELECT cod_moneda
         INTO v_cod_mon_pago
      FROM ge_cuentas
      WHERE nro_cuenta = v_nro_cta_proveedor;
      /*validar que la moneda de pago sea igual a la de la solicitud*/
      IF G_COD_MON_FACTURA != v_cod_mon_pago then
         raise_application_error(-20099, 'Moneda de la Cuenta diferente a la del Comprobante');
      end if;
      
      /*Validar que la cuenta sea valida*/
      pag_cta.pr_obt_cuenta(v_nro_cta_proveedor);
      IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
        raise_application_error(-20098, 'Recup.Cta '||v_nro_cta_proveedor||'.'||pag_cta.fu_obt_msj_error());
      END IF;
      
      IF v_cod_mon_pago IS NULL THEN
         --v_cod_mon_pago := pag_gen.fu_obt_mon_local;
         v_cod_mon_pago :=  G_COD_MON_FACTURA;
      END IF;
   ELSE
      
      --v_cod_mon_pago := pag_gen.fu_obt_mon_local;
      v_cod_mon_pago :=  G_COD_MON_FACTURA;
   END IF;
   
   
   
   
   
   
   
   
   return v_cod_mon_pago;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al Obtener la moneda de pago. '||SQLERRM);
  END;

  FUNCTION fu_obt_cta_proveedor(p_cod_ent_proveedor      IN NUMBER) RETURN VARCHAR2 IS
    v_cod_mon_pago VARCHAR2(20);
    v_nro_cta_proveedor varchar(15);

  BEGIN
   v_nro_cta_proveedor := fug_obt_parentes(p_cod_ent_proveedor, 'NRO_CTA_PPROV');

   return v_nro_cta_proveedor;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al Obtener la cta del proveedor. '||SQLERRM);
  END;

  FUNCTION fu_gen_cod_compra(p_cod_ent_proveedor      IN NUMBER) RETURN number IS
    v_cod_compra number(20);

  BEGIN
   v_cod_compra := s_cod_compra.nextval;

   return v_cod_compra;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al generar cod compra. '||SQLERRM);
  END;

  FUNCTION fu_obt_cod_compra(p_cod_ent_proveedor      IN NUMBER) RETURN number IS
    v_cod_compra number(20);

  BEGIN
   v_cod_compra := s_cod_compra.currval;

   return v_cod_compra;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al generar cod compra. '||SQLERRM);
  END;

  FUNCTION fu_exe_funcion(P_FUNCION in varchar2
                         ,P_PARAMETRO in varchar2) RETURN VARCHAR2 IS

    v_resultado varchar2(2000);
  BEGIN

    execute immediate 'begin :result := ' || P_FUNCION || '; end;'
            using out v_resultado, P_PARAMETRO;

    return v_resultado;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al ejecutar funcion dinamica. '||SQLERRM);
  END;

  function fu_obt_ruc_ente(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type) return varchar2 is

   V_NRO_DOCUMENTO varchar2(200);
  begin

     select case
               when TIPO = 'F' then
                DECODE(TIP_IVA,
                       'CO',
                       NRO_DOCUMENTO || '-' ||
                       replace(FUE_OBT_RUC_DIG_VERIFICADOR(trim(NRO_DOCUMENTO)), '-', ''),
                       '---')
               when TIPO = 'J' then
                NRO_DOCUMENTO
            end DOCUMENTO
       into V_NRO_DOCUMENTO
       from BA_PERSONAS
      where COD_PERSONA = P_COD_PERSONA;

     return V_NRO_DOCUMENTO;

  exception
     when NO_DATA_FOUND then
        return('Persona no registrada en el Sistema');
  end;

  FUNCTION fu_obt_crm_url(p_cod_ente in varchar2) return varchar2 is
  begin
     return  g_url_crm;
  end;
  
  FUNCTION fu_obt_for_pago(p_cod_ente in varchar2) return varchar2 is
    v_nro_cta_proveedor varchar(15);
  begin
     v_nro_cta_proveedor := fug_obt_parentes(p_cod_ente, 'NRO_CTA_PPROV');
     if v_nro_cta_proveedor is NOT NULL THEN
        RETURN 'C';
     else
        return null;
     end if;
  end;
  
  FUNCTION fu_obt_msj_error(P_MENSAJE in varchar2) return varchar2 is
    V_MENSAJE VARCHAR2(2000);
  begin
     
     IF P_MENSAJE = 'Error Insertando Registro  - SQL_UTIL.EJECUTE_DML ORA-00001: restriccion unica (IT.UK_KCOM_COD_ENTE) violada' THEN
        V_MENSAJE := 'La factura ya se encuentra cargada en ITGF';
     elsif P_MENSAJE = 'Error Insertando Registro  - SQL_UTIL.EJECUTE_DML ORA-01400: no se puede realizar una insercion NULL en (-IT-.-PV_COMPRAS-.-COD_ENT_PROVEEDOR-)' then
        V_MENSAJE := 'Falta ingresar el codigo ente del proveedor en CRM';
     else 
        V_MENSAJE := P_MENSAJE;
     END IF;
     
     RETURN V_MENSAJE;
  end;
  
  
  FUNCTION fu_obt_ruc_proveedor(p_cod_ente in varchar2) return varchar2 is
     V_NRO_DOCUMENTO varchar2(200);
  begin
     BEGIN
        Select pag_con.fu_obt_ruc_ente(A.COD_PERSONA)
           INTO V_NRO_DOCUMENTO
        From GE_ENTES A WHERE A.COD_ENTE = p_cod_ente;
     exception
        when no_data_found then
           v_nro_documento := '0';
        WHEN OTHERS THEN
           raise_application_error(-20035, 'Error al obtener ruc. '||SQLERRM);
     END;
     return V_NRO_DOCUMENTO;
  end;
  
  FUNCTION fu_obt_nom_proveedor(p_cod_ente in varchar2) return varchar2 is
      v_nom_ente ge_entes.descripcion%type;
  begin
     BEGIN
        Select a.descripcion
           INTO v_nom_ente
        From GE_ENTES A WHERE A.COD_ENTE = p_cod_ente;
     exception
        when no_data_found then
           v_nom_ente := 'NOMBRE NO ENCONTRADO';
        WHEN OTHERS THEN
           raise_application_error(-20035, 'Error al obtener nombre del ente. '||SQLERRM);
     END;
     return v_nom_ente;
  end;
END PAG_CON;
/

