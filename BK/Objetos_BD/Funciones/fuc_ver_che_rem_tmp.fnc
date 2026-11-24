CREATE OR REPLACE FUNCTION IT.FUC_VER_CHE_REM_TMP
(P_COD_BANCO    cc_che_remitidos_tmp.cod_banco%TYPE,
 P_NRO_CHEQUE   cc_che_remitidos.nro_cheque%TYPE,
 P_MONTO        cc_che_remitidos.monto%TYPE,
 P_TIP_DATO     cc_che_remitidos.tip_dato%TYPE)
  return varchar2 is
--18/07/2013 DI PN: verifica si el cheque migrado de la lectora coincide con el Core

  v_exi_che_enviados varchar2(1);
  v_ver_che_fue_env  varchar2(1);
  v_fec_importacion  date;
  v_des_error        varchar2(4000);
  v_exi_nro_cheque   varchar2(1);
  v_cod_moneda       cc_che_enviados.cod_moneda%TYPE;
  v_exi_banco        varchar2(1);
  v_exi_monto        varchar2(1);
  v_exi_custodia     varchar2(1);
  v_estado           varchar2(1);
begin
  -- 18/07/2013 DI PN:
  /*Si el tipo de importación es CIDESA (tip_dato = '1') retorna GS y si es BCP (tip_dato='2') retorna USD*/

  IF P_TIP_DATO = 1 THEN
     v_cod_moneda := 'GS';
  ELSE
     v_cod_moneda := 'USD';
  END IF;

  begin
    SELECT distinct 'S'
      INTO v_exi_che_enviados
      FROM cc_che_enviados
     WHERE cod_banco = p_cod_banco
       AND nro_cheque = p_nro_cheque
       AND monto = p_monto
       AND cod_moneda = v_cod_moneda
       AND fec_envio IS NULL
       AND estado = 'I'; -- Agregado el filtro por estado. SC 9866 - DYDMR-1334 - EGC-09/12/2014
  exception
    when others then
       v_exi_che_enviados := 'N';
  end;

  -- 23/07/2013 DI PN:
  /*Despliega el error de inconsistencia entre el CANNON Y EL CORE*/

  IF NVL(V_EXI_CHE_ENVIADOS, 'N') = 'N' THEN
    
     BEGIN
       SELECT DISTINCT 'S'
         INTO v_exi_custodia
         from ge_che_custodias c
        where c.cod_banco = p_cod_banco
          and c.nro_cheque = p_nro_cheque
          and c.cod_moneda = v_cod_moneda
          and c.monto = p_monto
          and c.estado = 'A';
     EXCEPTION
        WHEN OTHERS THEN 
          v_exi_custodia := 'N';
     END;
        
     IF nvl(v_exi_custodia, 'N') = 'S' THEN
        v_des_error := 'El cheque corresponde a un Proceso de Descuento de Cheques.';
     ELSE
    
      -- Verifica el nro de cheque

       BEGIN
         SELECT distinct 'S'
           INTO v_exi_nro_cheque
           FROM cc_che_enviados
          WHERE nro_cheque = p_nro_cheque
            AND cod_moneda = v_cod_moneda
            AND fec_envio is null;
        EXCEPTION
          WHEN OTHERS THEN
             v_exi_nro_cheque := 'N';
        END;

        IF nvl(v_exi_nro_cheque, 'N') = 'N' then
           v_des_error := 'No se encuentra el Nro de Cheque con la Moneda '||v_cod_moneda;
        ELSE
          BEGIN
            SELECT distinct 'S'
              INTO v_exi_banco
              FROM cc_che_enviados
             WHERE nro_cheque = p_nro_cheque
               AND cod_moneda = v_cod_moneda
               AND cod_banco = p_cod_banco
               AND fec_envio is null;
          EXCEPTION
            WHEN OTHERS THEN
               v_exi_banco := 'N';
          END;

          IF nvl(v_exi_banco, 'N') = 'N' THEN
             v_des_error := 'No coincide el cod de banco con el CORE';
          END IF;

   

          BEGIN
            SELECT distinct 'S'
              INTO v_exi_monto
              FROM cc_che_enviados
             WHERE nro_cheque = p_nro_cheque
               AND cod_moneda = v_cod_moneda
               AND monto = p_monto
               AND fec_envio is null;
          EXCEPTION
            WHEN OTHERS THEN
               v_exi_monto := 'N';
          END;


          IF nvl(v_exi_monto, 'N') = 'N' THEN
             IF v_des_error is null THEN
                v_des_error := 'No coincide el monto del cheque con el CORE';
             else
                v_des_error := 'No coincide el cod. de banco y el monto del cheque con el CORE';
             END IF;
          END IF;
          /* Agregado para mostrar un mensaje de error en caso de tener un estado <> 'I' */
          -- SC 9866 - DYDMR-1334 - EGC-09/12/2014
          BEGIN
            SELECT estado
              INTO v_estado 
              FROM cc_che_enviados
             WHERE nro_cheque = p_nro_cheque
               and cod_banco = p_cod_banco
               AND cod_moneda = v_cod_moneda
               AND monto = p_monto
               AND fec_envio is null;
          EXCEPTION
            WHEN OTHERS THEN
              v_estado := 'I';
          END;
          IF nvl(v_estado, 'N') <> 'I' THEN
             v_des_error := 'El estado del cheque es distinto a I (Ingresado). Su estado actual es: '||v_estado||' ('||fue_obt_des_refcodes('EST_ENVIADOS',v_estado)||')';
          END IF;

       END IF;
    END IF;

  END IF;


  --18/07/2013 DI PN:
  /*Verifica que el cheque que se encuentra en el temporal y fue enviado correctamente no figure como error.
    Esto se debe a que el temporal se limpia antes de la importación*/

  begin
    select fecha
      into v_fec_importacion
      from cc_che_remitidos_tmp
     where cod_banco = p_cod_banco
       and nro_cheque = p_nro_cheque
       and monto = p_monto;
  exception
    when others then
       v_fec_importacion := null;
  end;

  begin
    SELECT distinct 'S'
      INTO v_ver_che_fue_env
      FROM cc_che_enviados
     WHERE cod_banco = p_cod_banco
       AND nro_cheque = p_nro_cheque
       AND monto = p_monto
       AND estado = 'E'
       AND trunc(fec_envio) = trunc(v_fec_importacion);
  exception
    when others then
       v_ver_che_fue_env := 'N';
  end;

  if nvl(v_exi_che_enviados, 'N') = 'N'  and nvl(v_ver_che_fue_env, 'N') = 'N' then
     return v_des_error;
  else
     return 'OK';
  end if;
  
end FUC_VER_CHE_REM_TMP;
/

