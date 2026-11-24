create or replace function it.fub_obt_val_deposito(p_nro_cuenta varchar2,p_monto number) return varchar is
  v_tot_credito ah_sal_mensuales.tot_creditos%type := 0;
  v_tot_credito_usd ah_sal_mensuales.tot_creditos%type;
  v_cod_persona ba_personas.cod_persona%type;
  v_cod_moneda ba_monedas.cod_moneda%type;
  v_mto_límite cr_per_tip_operaciones.mto_limite%type;
  v_credito cr_per_tip_operaciones.mto_limite%type :=0;
  v_umbral_fisica  number(18) := to_number(fug_obt_pardinamico('IMP_MAX_DEP_FIS')); --Val: 10.000USD
  v_umbral_juridica number(18) := to_number(fug_obt_pardinamico('IMP_MAX_DEP_JUR')); --Val: 50.000USD
  v_tip_persona varchar2(1) := 'F';
  v_fcdehoy date;
  BEGIN
  --Recuperar el LOA por cod_persona
      begin
         v_fcdehoy := pag_cal.fu_obt_fec_actual(3);
         v_cod_persona := fug_obt_cli_principal(p_nro_cuenta, 'P'); --recupera el cod persona principal de la cuenta
        
        --recuperamos la moneda del LOA
        select distinct b.cod_moneda
          into v_cod_moneda
          from cr_per_tip_operaciones b
         where b.cod_persona = v_cod_persona;
         
        --recuperamos el monto límite del LOA (sumatoria)
        select sum(b.mto_limite)
          into v_mto_límite --Loa
          from cr_per_tip_operaciones b
         where b.cod_persona = v_cod_persona;
      exception
        when others then
          raise_application_error(-20000,'En obtener datos del LOA. '||sqlerrm);
      end;

   --SQL del total de créditos AHORROS/CTA CORRIENTE filtro por persona
      begin  
           select sum (TOT_CREDITO) into v_tot_credito
from (
SELECT SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',NVL(A.MONTO, 0),0)) TOT_CREDITO
            FROM GE_TRANSACCIONES B, GE_MOVIMIENTOS A, ge_cta_clientes c, ge_cuentas x
            WHERE c.cod_persona = v_cod_persona --descomentar si queremos filtrar por persona
              and to_char(a.fecha,'YYYY') = to_char(v_fcdehoy,'YYYY')
              and to_char(a.fecha,'MM') = to_char(v_fcdehoy,'MM')
              and c.relacion   = 'P'
              and c.nro_cuenta = a.nro_cuenta
              and x.cod_moneda = 'USD'
              and x.nro_cuenta = c.nro_cuenta
              and x.nro_cuenta = a.nro_cuenta
              AND A.ESTADO           = 'N'
              AND A.COD_MODULO       = B.COD_MODULO
              AND A.COD_MODALIDAD    = B.COD_MODALIDAD
              AND A.COD_TRANSACCION  = B.COD_TRANSACCION
              AND B.VE_CLIENTE       = 'S'
              AND B.TIPO             IN ('C', 'D')
              AND NVL(B.AFECTA,'XX') != 'B'
            GROUP BY  c.cod_persona,TO_CHAR(A.FECHA,'MM'),TO_CHAR(A.FECHA,'YYYY')
   union 
   SELECT SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',NVL(A.MONTO, 0),0)) TOT_CREDITO
            FROM GE_TRANSACCIONES B, ah_movimientos_his A, ge_cta_clientes c, ge_cuentas x
            WHERE c.cod_persona = v_cod_persona --descomentar si queremos filtrar por persona
              and to_char(a.fecha,'YYYY') = to_char(v_fcdehoy,'YYYY')
              and to_char(a.fecha,'MM') = to_char(v_fcdehoy,'MM')
              and c.relacion   = 'P'
              and c.nro_cuenta = a.nro_cuenta
              and x.cod_moneda = 'USD'
              and x.nro_cuenta = c.nro_cuenta
              and x.nro_cuenta = a.nro_cuenta
              AND A.ESTADO           = 'N'
              AND A.COD_MODULO       = B.COD_MODULO
              AND A.COD_MODALIDAD    = B.COD_MODALIDAD
              AND A.COD_TRANSACCION  = B.COD_TRANSACCION
              AND B.VE_CLIENTE       = 'S'
              AND B.TIPO             IN ('C', 'D')
              AND NVL(B.AFECTA,'XX') != 'B'
            GROUP BY  c.cod_persona,TO_CHAR(A.FECHA,'MM'),TO_CHAR(A.FECHA,'YYYY')
     union
     SELECT SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',NVL(A.MONTO, 0),0)) TOT_CREDITO
            FROM GE_TRANSACCIONES B, cc_movimientos_his A, ge_cta_clientes c, ge_cuentas x
            WHERE c.cod_persona = v_cod_persona --descomentar si queremos filtrar por persona
              and to_char(a.fecha,'YYYY') = to_char(v_fcdehoy,'YYYY')
              and to_char(a.fecha,'MM') = to_char(v_fcdehoy,'MM')
              and c.relacion   = 'P'
              and c.nro_cuenta = a.nro_cuenta
              and x.cod_moneda = 'USD'
              and x.nro_cuenta = c.nro_cuenta
              and x.nro_cuenta = a.nro_cuenta
              AND A.ESTADO           = 'N'
              AND A.COD_MODULO       = B.COD_MODULO
              AND A.COD_MODALIDAD    = B.COD_MODALIDAD
              AND A.COD_TRANSACCION  = B.COD_TRANSACCION
              AND B.VE_CLIENTE       = 'S'
              AND B.TIPO             IN ('C', 'D')
              AND NVL(B.AFECTA,'XX') != 'B'
            GROUP BY  c.cod_persona,TO_CHAR(A.FECHA,'MM'),TO_CHAR(A.FECHA,'YYYY'));
        exception 
          when others  then 
            v_tot_credito := 0;
         end; 
    --Validamos si es persona F o J    
      If pag_gen.fu_es_per_fisica(v_cod_persona) = 'N' then
         v_tip_persona := 'J';
      Else
         v_tip_persona := 'F';
      End if;
      
  if v_cod_moneda = 'USD' then
        v_credito := nvl(v_tot_credito,0) + nvl( p_monto,0); --total en creditos mes/aaaa más monto a depositar
        
        if v_tip_persona = 'F' then
          If v_umbral_fisica + v_mto_límite > v_credito then
            return 'N';
          else 
            return 'S';
          end if;
         elsif v_tip_persona = 'J' then
             If v_umbral_juridica + v_mto_límite > v_credito then
              return 'N'; --No se deposita 
            else 
              return 'S'; --Si se deposita
            end if;
         end if;
     elsif v_cod_moneda = 'GS' then 
        v_tot_credito_usd := it.PAG_GEN.FU_CON_MON_A_MONEDA('GS','USD', v_mto_límite);
        
        v_credito := nvl(v_tot_credito,0) + nvl( p_monto,0); --total en creditos mes/aaaa más monto a depositar
        --Monto a depositar > LOA + umbral.--rechaza cod 61
        if v_tip_persona = 'F' then
          If v_umbral_fisica + v_tot_credito_usd > v_credito then
            return 'N';
          else 
            return 'S';
          end if;
         elsif v_tip_persona = 'J' then
             If v_umbral_juridica + v_tot_credito_usd > v_credito then
              return 'N'; --No se deposita 
            else 
              return 'S'; --Si se deposita
            end if;
         end if;
     end if;

end fub_obt_val_deposito;

 
/
