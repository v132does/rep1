CREATE OR REPLACE PROCEDURE IT.PRA_CRE_TOT_BATCH
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_COD_OFICINA IN GE_MOVIMIENTOS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
 ,P_COD_MODALIDAD IN GE_MOVIMIENTOS.COD_MODALIDAD%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_EST_CUENTA IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
 ,P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_REVERSADO IN GE_MOVIMIENTOS.REVERSADO%TYPE
 )
 IS

V_MES NUMBER(2, 0);
V_ANIO NUMBER(4, 0);
V_MSJ_ERROR VARCHAR2(100);
BEGIN
     v_msj_error := null;
     v_anio := to_number(to_char(to_date(p_fecha,'DDMMYYYY'),'YYYY'));
     v_mes := to_number(to_char(to_date(p_fecha,'DDMMYYYY'),'MM'));

          if p_cod_modalidad = 31 then
              update AH_CTA_VISTAS
              set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(p_monto,0)
                           where COD_MODALIDAD = p_cod_modalidad
                             and COD_OFICINA = p_cod_oficina
                             and NRO_CUENTA = p_nro_cuenta;
              if sql%notfound then
                 v_msj_error:= 'No existe dato en Ahorro a la Vista, # '||
                 p_nro_cuenta;

              end if;
          end if;
          if p_cod_modalidad in (32,37,38) then
              update AH_CTA_PLAZOS
              set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(p_monto,0)
                           where COD_MODALIDAD = p_cod_modalidad
                             and COD_OFICINA = p_cod_oficina
                             and NRO_CUENTA = p_nro_cuenta;
              if sql%notfound then
                 v_msj_error:= 'No existe dato en Ahorro a Plazo Fijo, # '||
                 p_nro_cuenta;
              end if;
          end if;
          if p_cod_modalidad IN (33,34,35,36) then
              update AH_CTA_CERTIFICADOS
              set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(p_monto,0)
                           where COD_MODALIDAD = p_cod_modalidad
                             and COD_OFICINA = p_cod_oficina and
                                 NRO_CUENTA = p_nro_cuenta;
              if sql%notfound then
                 v_msj_error:= 'No existe dato en Certificados, # '||
                 p_nro_cuenta;
              end if;
          end if;
          if p_cod_modalidad = 41 OR p_cod_modalidad = 42 THEN
              update CC_CTA_CORRIENTES
              set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(p_monto,0)
                           where COD_MODALIDAD = p_cod_modalidad
                             and COD_OFICINA = p_cod_oficina
                             and NRO_CUENTA = p_nro_cuenta;
             if sql%notfound then
                 v_msj_error:= 'No existe dato en Cuenta Corriente, # '||
                 p_nro_cuenta;
              end if;
          end if;
      -----------

EXCEPTION
     WHEN OTHERS Then
          RAISE_APPLICATION_ERROR (-20002,p_nro_cuenta||' Importe '||
                                   p_monto||' PRA_CRE_TOT_BATCH');
END;
/

