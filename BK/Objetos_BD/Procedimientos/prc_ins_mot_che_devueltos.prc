CREATE OR REPLACE PROCEDURE IT.PRC_INS_MOT_CHE_DEVUELTOS(p_cod_moneda IN VARCHAR2) IS
--
  c_devtmp        cc_che_devueltos_tmp%rowtype;
  v_fecha         date := pag_cal.fu_obt_fec_actual(4);
  v_cod_moneda    cc_che_devueltos.cod_moneda%type;
  v_imp_alt_valor ge_par_dinamicos.val_parametro%type := to_number(fug_obt_pardinamico('MTO_CHE_RET_CERO', null, null, v_cod_moneda));
  v_tip_importe   number := 0;
  v_cod_cau_principal varchar2(20);
  -- Cursor Principal de Cheques Rechazados a Procesar--
  CURSOR c_chdev is
     SELECT c.*
       FROM cc_che_devueltos_tmp c
      WHERE trunc(c.fec_insercion) = trunc(sysdate)
        AND c.cod_moneda = v_cod_moneda
      ORDER BY nro_linea, nro_cuenta;
  --
  --Insertar en CC_CHE_DEVUELTOS_DET
  PROCEDURE pr_ins_cc_che_devueltos_det IS
    v_longitud        number(2);
    v_posicion        number(2) := 1;
    v_cod_causa       cc_che_devueltos_det.cod_causa%type;
    v_cod_cau_dev_bcp varchar2(2);
  BEGIN
    v_longitud := round(length(c_devtmp.cod_cau_dev_bcp_det)/2);
    FOR i in 1..v_longitud LOOP
        v_cod_cau_dev_bcp := substr(c_devtmp.cod_cau_dev_bcp_det, v_posicion, 2);
        BEGIN
          SELECT MAX(z.cod_causa)
            INTO v_cod_causa
            FROM ge_par_causales z
           WHERE z.parametro = 'COD_DEV_BCP'
             AND to_number(z.val_parametro) = v_cod_cau_dev_bcp;
        EXCEPTION
           WHEN OTHERS THEN
             v_cod_causa := null;
        END;
        IF v_cod_causa IS NOT NULL THEN
          INSERT INTO cc_che_devueltos_det
            (fecha, nro_cuenta, nro_cheque, cod_moneda,
             cod_causa, cod_cau_dev_bcp, tip_importe)
          VALUES
            (v_fecha, c_devtmp.nro_cuenta, c_devtmp.nro_cheque, c_devtmp.cod_moneda,
             v_cod_causa, v_cod_cau_dev_bcp, v_tip_importe);
        END IF;
        v_posicion := v_posicion + 2;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20099, 'Error en PR_INS_CC_CHE_DEVUELTOS_DET. - '||sqlerrm);
  END;
  PROCEDURE pr_act_cc_che_devueltos IS
     v_es_numerico number;
  BEGIN
     BEGIN
   --
          SELECT to_number(fug_rem_car_especiales(c_devtmp.cod_submotivo_det,'0.,','   '))
          INTO   v_es_numerico
          FROM   dual;
     EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20099, 'Error al validar sumbotivos. Cheque-Cuenta ' ||c_devtmp.nro_cheque||'-'||c_devtmp.nro_cuenta||'. - '||sqlerrm);
     END;
     BEGIN
   --
       UPDATE CC_CHE_DEVUELTOS d
       SET    d.cod_submotivo_det = c_devtmp.cod_submotivo_det
       WHERE  d.nro_cuenta = c_devtmp.nro_cuenta
       AND    d.nro_cheque = c_devtmp.nro_cheque
       AND    d.fecha      = v_fecha;--c_devtmp.fec_proceso;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           NULL;
     END;
  EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20099, 'Error en PR_ACT_CC_CHE_DEVUELTOS. Cheque-Cuenta ' ||c_devtmp.nro_cheque||'-'||c_devtmp.nro_cuenta||'. - '||sqlerrm);
  end;

--Inicio proceso
BEGIN
  IF p_cod_moneda = 'G' THEN
     v_cod_moneda := pag_gen.fu_obt_mon_local;
  ELSIF p_cod_moneda = 'U' THEN
     v_cod_moneda := pag_gen.fu_obt_mon_fuerte;
  END IF;


  BEGIN
    SELECT 1
      INTO v_tip_importe
      FROM cc_che_devueltos_tmp t
     WHERE trunc(t.fec_insercion) = trunc(sysdate)
       AND t.cod_moneda = v_cod_moneda
       AND t.monto >= v_imp_alt_valor
       AND rownum = 1;
  EXCEPTION
    WHEN OTHERS THEN
      v_tip_importe := 0;
  END;
  DELETE cc_che_devueltos_det d
   WHERE d.fecha = v_fecha
     AND d.cod_moneda = v_cod_moneda
     AND d.tip_importe = v_tip_importe;
  FOR c IN c_chdev LOOP
       --OBTENEMOS COD_CAU_PRINCIPAL
        v_cod_cau_principal:= null;
        begin
          select COD_CAUSA
             into v_cod_cau_principal
                 from ge_par_causales
                   where VAL_PARAMETRO= lpad(NVL(C.COD_CAU_DEV_BCP,'01'),2,'0')
                     and parametro = 'COD_DEV_BCP'
                     AND ROWNUM=1;
        exception
          when no_data_found then
             v_cod_cau_principal:=null;
          when others then
             v_cod_cau_principal:=null;
        end;  

    if v_cod_cau_principal is not null then 
      update cc_che_devueltos_tmp a
           set a.cod_cau_principal=v_cod_cau_principal
            where a.nro_cuenta= c.nro_cuenta
              and a.nro_cheque=c.nro_cheque;
    end if;

      c_devtmp := c;
      IF c_devtmp.cod_cau_dev_bcp_det IS NOT NULL THEN
         pr_ins_cc_che_devueltos_det;
      END IF;

      --update CC_CHE_DEVUELTOS
      IF c_devtmp.cod_submotivo_det IS NOT NULL THEN
         pr_act_cc_che_devueltos;
      END IF;

  END LOOP;

  --Ajuste para guardar fecha de Sistema
  update cc_che_devueltos_tmp a
   set a.fecha=to_char(v_fecha,'dd/mm/yyyy');

END;
/
