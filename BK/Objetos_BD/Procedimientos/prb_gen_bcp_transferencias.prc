create or replace PROCEDURE it.PRB_GEN_BCP_TRANSFERENCIAS is
p_fecha date :=fug_obt_fec_anterior(1);
p_archivo varchar2(100);
p_corte number := 10000000;

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_CAB varchar2(1000) := '';
V_SQL varchar2(1000) := '';

    PROCEDURE lp_transf_recibidas
    AS
    BEGIN
        p_archivo  := 'TRANSF_BCP_RECIBIDAS_'||TO_CHAR(p_fecha,'YYYYMMDD');
         --Poblar la tabla temporal con controles
        INSERT INTO IT.GE_TRA_BCP_REC_TMP        
        SELECT ROWNUM NRO_REGISTRO, A.*
        FROM (
            SELECT T.COD_MONEDA,
                 B.DESCRIPCION,
                 R.ABREVIATURA,
                 T.NRO_REFERENCIA,
                 T.NRO_REF_EXTERNA,
                 INITCAP (T.NOM_BENEFICIARIO) NOM_BENEFICIARIO,
                 T.NRO_CTA_BENEFICIARIO NRO_CTA,
                 T.NRO_CTA_PTE_BENEFICIARIO CTA_ENT_BENEF,
                 INITCAP (T.NOM_SOLICITANTE) NOM_SOLICITANTE,
                 T.NRO_CTA_SOLICITANTE NRO_CTA_SOL,
                 T.NRO_CTA_PTE_SOLICITANTE CTA_ENT_SOL,
                 T.FEC_INGRESO,
                 T.FEC_VALOR,
                 T.ORIGEN,
                 T.PLATAFORMA,
                 P.PARTICIPANTE,
                 FUE_OBT_DES_REFCODES('EST_MSJ_SNP', T.ESTADO) ESTADO,
                 FUE_OBT_DES_REFCODES('SITUACION', T.SITUACION) SITUACION,
                 T.MONTO,
                 T.COD_TIP_OPERACION,
                 T.COD_SUB_TIP_OPERACION,
                 T.HORA
            FROM GE_SNP_TRANSFERENCIAS T,
                 GV_SNP_PARTICIPANTES P,
                 BA_MONEDAS B,
                 BA_COD_REFERENCIAS R             
           WHERE T.NRO_REF_EXTERNA IS NOT NULL
             AND T.COD_SWI_PTE_SOLICITANTE = P.COD_SWIFT
             AND T.COD_MONEDA = B.COD_MONEDA
             AND R.VAL_MINIMO = T.COD_MSJ_SWIFT
             AND R.DOMINIO = 'COD_MSJ_SWIFT'
             AND T.COD_MONEDA = 'GS'
             AND R.ABREVIATURA in ('MENSAJE 102', 'MENSAJE 103', 'MENSAJE 202', 'MT102')
             AND T.FEC_VALOR = p_fecha
        ORDER BY T.FEC_VALOR,
                 T.COD_MONEDA,
                 T.ESTADO,
                 T.COD_MSJ_SWIFT,
                 T.NRO_REFERENCIA
        )A;
        
		SELECT COUNT(*) INTO v_cant
        FROM IT.GE_TRA_BCP_REC_TMP;
      
        -- redondeo por exceso parcheado
        v_paginas := round(v_cant/p_corte) + 1;

        -- Generar nombre archivo
        v_nom  := p_archivo || '.csv';
        v_cont := 1;
        v_ini  := 1;
        v_fin  := p_corte;
        
		--se inserta la cabecera
        V_CAB := 'SELECT ''COD_MONEDA;DESCRIPCION;ABREVIATURA;NRO_REFERENCIA;NRO_REF_EXTERNA;NOM_BENEFICIARIO;NRO_CTA;CTA_ENT_BENEF;NOM_SOLICITANTE;NRO_CTA_SOL;CTA_ENT_SOL;FEC_INGRESO;FEC_VALOR;ORIGEN;PLATAFORMA;PARTICIPANTE;ESTADO;SITUACION;MONTO;COD_TIP_OPERACION;COD_SUB_TIP_OPERACION;HORA;'' FROM dual';

        PRG_GEN_ARCHIVO_TXT(trim(V_NOM),V_CAB,'N',null,'N');

        --se inserta el detalle
        FOR v_cont IN 1 .. v_paginas LOOP
            V_SQL := '
            SELECT COD_MONEDA,
                   DESCRIPCION,
                   ABREVIATURA,
                   NRO_REFERENCIA,
                   NRO_REF_EXTERNA,
                   NOM_BENEFICIARIO,
                   NRO_CTA,
                   CTA_ENT_BENEF,
                   NOM_SOLICITANTE,
                   NRO_CTA_SOL,
                   CTA_ENT_SOL,
                   FEC_INGRESO,
                   FEC_VALOR,
                   ORIGEN,
                   PLATAFORMA,
                   PARTICIPANTE,
                   ESTADO,
                   SITUACION,
                   MONTO,
                   COD_TIP_OPERACION,
                   COD_SUB_TIP_OPERACION,
                   HORA
            FROM IT.GE_TRA_BCP_REC_TMP
            WHERE NRO_REGISTRO BETWEEN ' || v_ini || ' AND ' || v_fin;                    
            
            PRG_GEN_ARCHIVO_TXT(TRIM(V_NOM), V_SQL, 'N', ';', 'S');

            v_ini := v_fin + 1;
            v_fin := v_fin + p_corte;

            v_cont2 := v_cont2 + 1;
        END LOOP; --Fin loop por detalle   
	END;

    PROCEDURE lp_transf_enviadas
    AS
    BEGIN
        p_archivo  := 'TRANSF_BCP_ENVIADAS_'||TO_CHAR(p_fecha,'YYYYMMDD');
        
		--Poblar la tabla temporal con controles
        INSERT INTO IT.GE_TRA_BCP_ENV_TMP
        SELECT ROWNUM, A.*
        FROM (
            SELECT    T.COD_MONEDA,
                      B.DESCRIPCION,
                      R.ABREVIATURA TIPO_MENSAJERÍA,
                      T.NRO_REFERENCIA,
                      T.NRO_REF_EXTERNA,
                      INITCAP (T.NOM_SOLICITANTE) NOM_SOLICITANTE,
                      T.NRO_CTA_SOLICITANTE NRO_CTA,
                      T.NRO_CTA_PTE_SOLICITANTE CTA_ENT_SOL,
                      INITCAP (T.NOM_BENEFICIARIO) NOM_BENEFICIARIO,
                      T.NRO_CTA_BENEFICIARIO NRO_CTA_BENEF,
                      T.NRO_CTA_PTE_BENEFICIARIO CTA_ENT_BENEF,
                      T.FEC_INGRESO,
                      T.FEC_VALOR,
                      T.ORIGEN,
                      T.PLATAFORMA,
                      P.PARTICIPANTE PARTICIPANTE_DESTINO,
                      FUE_OBT_DES_REFCODES('EST_MSJ_SNP', T.ESTADO) ESTADO,
                      FUE_OBT_DES_REFCODES('SITUACION', T.SITUACION) SITUACION,
                      T.MONTO,
                      T.COD_TIP_OPERACION,
                      T.COD_SUB_TIP_OPERACION,
                      T.HORA
            FROM       GE_SNP_TRANSFERENCIAS T,
                       GV_SNP_PARTICIPANTES P,
                       BA_MONEDAS B,
                       BA_COD_REFERENCIAS R
            WHERE      T.NRO_REF_EXTERNA IS NULL
            AND        T.COD_SWI_PTE_BENEFICIARIO = P.COD_SWIFT
            AND        T.COD_MONEDA = B.COD_MONEDA
            AND        R.VAL_MINIMO = T.COD_MSJ_SWIFT
            AND        R.DOMINIO = 'COD_MSJ_SWIFT'
            AND         T.COD_MONEDA = 'GS'
            AND         R.ABREVIATURA in('MENSAJE 103', 'MENSAJE 202', 'MT102')
            AND        T.FEC_VALOR = p_fecha
            ORDER BY T.FEC_VALOR,
                     T.COD_MONEDA,
                     T.ESTADO,
                     T.COD_MSJ_SWIFT,
                     T.NRO_REFERENCIA
        )A;
        
		SELECT COUNT(*) INTO v_cant
        FROM IT.GE_TRA_BCP_ENV_TMP;
        dbms_output.put_line('v_cant: '|| v_cant);

        -- redondeo por exceso parcheado
        v_paginas := round(v_cant/p_corte) + 1;

        -- Generar nombre archivo
        v_nom  := p_archivo || '.csv';
        v_cont := 1;
        v_ini  := 1;
        v_fin  := p_corte;
        
		--se inserta la cabecera
        V_CAB := 'SELECT ''COD_MONEDA;DESCRIPCION;TIPO_MENSAJERÍA;NRO_REFERENCIA;NRO_REF_EXTERNA;NOM_SOLICITANTE;NRO_CTA;CTA_ENT_SOL;NOM_BENEFICIARIO;NRO_CTA_BENEF;CTA_ENT_BENEF;FEC_INGRESO;FEC_VALOR;ORIGEN;PLATAFORMA;PARTICIPANTE_DESTINO;ESTADO;SITUACION;MONTO;COD_TIP_OPERACION;COD_SUB_TIP_OPERACION;HORA;'' FROM dual';

        PRG_GEN_ARCHIVO_TXT(trim(V_NOM),V_CAB,'N',null,'N');

        --se inserta el detalle
        FOR v_cont IN 1 .. v_paginas LOOP
            V_SQL := '
                SELECT COD_MONEDA,
                       DESCRIPCION,
                       TIPO_MENSAJERIA,
                       NRO_REFERENCIA,
                       NRO_REF_EXTERNA,
                       NOM_SOLICITANTE,
                       NRO_CTA,
                       CTA_ENT_SOL,
                       NOM_BENEFICIARIO,
                       NRO_CTA_BENEF,
                       CTA_ENT_BENEF,
                       FEC_INGRESO,
                       FEC_VALOR,
                       ORIGEN,
                       PLATAFORMA,
                       PARTICIPANTE_DESTINO,
                       ESTADO,
                       SITUACION,
                       MONTO,
                       COD_TIP_OPERACION,
                       COD_SUB_TIP_OPERACION,
                       HORA
            FROM IT.GE_TRA_BCP_ENV_TMP
            WHERE NRO_REGISTRO BETWEEN ' || v_ini || ' AND ' || v_fin;                    
        
			PRG_GEN_ARCHIVO_TXT(TRIM(V_NOM), V_SQL, 'N', ';', 'S');

            v_ini := v_fin + 1;
            v_fin := v_fin + p_corte;

            v_cont2 := v_cont2 + 1;
        END LOOP; --Fin loop por detalle
	END;
BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
    PAE_CNF.G_PROGRAMA   := 'GPPROFIN';
    
    BEGIN
        lp_transf_recibidas;
    EXCEPTION
        WHEN OTHERS THEN
            PRG_INS_LOG_PROGRAMAS( 
                p_cod_programa => 'PRB_GEN_BCP_TRANSFERENCIAS',
                p_det_error    => 'Error al generar el reporte de transferencias BCP recibidas:'||sqlerrm
            );
    END;
    BEGIN
        lp_transf_enviadas;
    EXCEPTION
        WHEN OTHERS THEN
            PRG_INS_LOG_PROGRAMAS( 
                p_cod_programa => 'PRB_GEN_BCP_TRANSFERENCIAS',
                p_det_error    => 'Error al generar el reporte de transferencias BCP enviadas:'||sqlerrm
            );
    END;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000, 'Error en PRB_GEN_REP_BCP_TRANSFERENCIAS' || SQLERRM);
END PRB_GEN_BCP_TRANSFERENCIAS;
