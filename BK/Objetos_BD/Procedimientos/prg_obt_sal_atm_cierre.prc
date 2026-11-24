CREATE OR REPLACE PROCEDURE IT.PRG_OBT_SAL_ATM_CIERRE(P_NRO_CUENTA IN VARCHAR2,
                                                   P_SAL_DISPONIBLE OUT NUMBER,
                                                   P_SAL_TOTAL OUT NUMBER,
                                                   P_SAL_RETENIDO OUT NUMBER,
                                                   P_SAL_BLOQUEADO OUT NUMBER,
                                                   P_TIE_ERROR OUT VARCHAR2,
                                                   P_MEN_ERROR OUT VARCHAR2) IS
   ------------------------------------------------------------------------------------------
   --Procedimiento que devuelve el Saldo Disponible cuando el ATM se encuentra en Cierre
   --Para Saldos de 31-Ahorro a la Vista y 41Cuentas Corrientes--
   ------------------------------------------------------------------------------------------
   --Este programa se debe utiizar cuando el ATM esta en Cierre y el resultado de la variable 
   --pag_cta.g_cod_error <> 0
   --despues de invocar al pag_cta.pr_obt_cuenta
   --El detalle de los erroes son :
     --g_cod_error := 14; --Cuentas Corrientes / g_msj_error := 'Estado del Modulo incorrecto';
     --g_cod_error := 13; --Ahorro Vista / g_msj_error := 'Estado del Modulo incorrecto';
   --Despues de invocar al pag_cta.pr_obt_cuenta necesariamente se debe valir el error:
     --if pag_cta.g_cod_error <> 0
   --El ATM esta en Cierre cuando el estado del Modulo de 3-Ahorros es 6-Actualizacion ATM
   --El Estado 6 se puede dar en el proceso 10-Inicio, o 1-Cierre--
   -------------------------------------------------------------------------------------------
   --Desarrollado por Ramon Pavon / 15.02.2016--
   -------------------------------------------------------------------------------------------
   --Variables-- 
   v_lugar      VARCHAR2(2000);
   v_sal_disponible cc_cta_corrientes.sal_total%type;
   v_sal_total cc_cta_corrientes.sal_total%type;
   v_sal_retenido cc_cta_corrientes.sal_total%type;
   v_sal_bloqueado cc_cta_corrientes.sal_total%type;
   v_cod_modulo ba_modulos.cod_modulo%type;
   v_ind_pendientes varchar2(1);
   v_hor_ini_10 varchar2(8);
   v_hor_fin_10 varchar2(8); 
   v_hor_ini_11 varchar2(8);
   v_hor_fin_11 varchar2(8); 
   v_cod_pro_encurso ge_procesos.cod_proceso%type;
   v_tie_error varchar2(1) := 'N';
   v_men_error varchar2(2000) := null;
   --Cursores--
   cursor c_cta_corrientes is
    select a.*
      from cc_cta_corrientes a
    WHERE a.nro_cuenta = p_nro_cuenta
      and EXISTS (SELECT 1
             FROM cc_cta_corrientes_noc c
            WHERE c.nro_cuenta = a.nro_cuenta
              AND (nvl(c.mto_deb_pendientes, 0) <> 0 OR nvl(c.mto_cre_a_confirmar, 0) > 0 OR
                  nvl(c.mto_cre_pendientes, 0) <> 0));

   cursor c_cta_vistas is
    select a.*
      from ah_cta_vistas a
    WHERE a.nro_cuenta = p_nro_cuenta
      and EXISTS (SELECT 1
             FROM ah_cta_vistas_noc c
            WHERE c.nro_cuenta = a.nro_cuenta
              AND (nvl(c.mto_deb_pendientes, 0) <> 0 OR nvl(c.mto_cre_a_confirmar, 0) > 0 OR
                  nvl(c.mto_cre_pendientes, 0) <> 0));
PROCEDURE PR_CER_VARIABLES IS
BEGIN
  P_SAL_DISPONIBLE := 0;
  P_SAL_TOTAL := 0;
  P_SAL_RETENIDO := 0;
  P_SAL_BLOQUEADO := 0;
END;

BEGIN
  --Inicializacion Variables--
  v_lugar := 'Inicializacion';
  v_sal_disponible := null;
  v_sal_total := null;
  v_sal_retenido := null;
  v_sal_bloqueado := null;
  
  --Verifica desde que programa ha sido llamado-- (10-Inicio, o 11-Cierre)
  v_lugar := 'Verificacion Proceso en curso';
  v_hor_ini_10 := null;
  v_hor_fin_10 := null;
  v_hor_ini_11 := null;
  v_hor_fin_11 := null;
  
  select z.hor_inicio, z.hor_fin
    into v_hor_ini_10, v_hor_fin_10
    from ge_procesos z
   where z.cod_proceso = 10; --Inicio--
  select z.hor_inicio, z.hor_fin
    into v_hor_ini_11, v_hor_fin_11
    from ge_procesos z
   where z.cod_proceso = 11; --Cierre--
  
  if ((v_hor_ini_10 is not null) and (v_hor_fin_10 is null) and (v_hor_ini_11 is null) and (v_hor_fin_11 is null)) then
     v_cod_pro_encurso := 10; --10-Inicio--
  elsif ((v_hor_ini_11 is not null) and (v_hor_fin_11 is null) and (v_hor_ini_10 is not null) and (v_hor_fin_10 is not null)) then
     v_cod_pro_encurso := 11; --11-Cierre--
  else
     v_tie_error := 'S';
     v_men_error := 'Error. No se puede determinar el proceso en curso';
     --raise_application_error(-20000, 'Error. No se puede determinar el proceso en curso');
  end if;
   
  if v_tie_error = 'N' then
     --Busca el Modulo de la cuenta--
     v_lugar := 'Busca Modulo de la Cuenta';
     Begin
        select a.cod_modulo
          INTO V_COD_MODULO
          from GE_cuentas a
         where a.NRO_CUENTA = P_NRO_CUENTA;
     Exception
        When NO_DATA_FOUND Then
           v_tie_error := 'S';
           v_men_error := 'Error en PRG_OBT_SAL_ATM_CIERRE. Cuenta '||P_NRO_CUENTA||' no Existe.'||sqlerrm;
           --raise_application_error(-20000, 'Error en PRG_OBT_SAL_ATM_CIERRE. Cuenta no Existe'||'-'||SQLERRM);
        when others then
           v_tie_error := 'S';
           v_men_error := 'Error en PRG_OBT_SAL_ATM_CIERRE'||'-'||SQLERRM; 
           --raise_application_error(-20000, 'Error en PRG_OBT_SAL_ATM_CIERRE'||'-'||SQLERRM);
      End;
   end if;
   
   if v_tie_error = 'N' then
       --Calcula el Disponible segun el Modulo--
       if v_cod_modulo = 4 then
          if v_cod_pro_encurso = 10 then --Inicio-- 
              v_lugar := 'Calculo de Saldo Cta.Cte-Inicio';
              v_ind_pendientes := 'N';
              --Si tiene mov pendientes a actualizar ingresa el cursor--
              for cte in c_cta_corrientes loop
                    v_ind_pendientes := 'S';
                    SELECT (nvl(cte.sal_total, 0) - nvl(b.mto_deb_pendientes, 0) +
                            nvl(b.mto_cre_a_confirmar, 0) + nvl(b.mto_cre_pendientes, 0)), 
                            (nvl(cte.sal_retenido, 0) + nvl(b.mto_cre_a_confirmar, 0)),
                            nvl(cte.sal_bloqueado, 0)
                      into v_sal_total, v_sal_retenido, v_sal_bloqueado
                      FROM cc_cta_corrientes_noc b
                     WHERE b.nro_cuenta = cte.nro_cuenta;
              end loop;
              --Si no ingreso a cursor de mov pendientes, utiliza calculo normal--
              if v_ind_pendientes = 'N' then
                 select nvl(SAL_TOTAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0),
                     nvl(SAL_RETENIDO,0), nvl(SAL_BLOQUEADO,0)
                into v_sal_total, v_sal_retenido, v_sal_bloqueado
                from cc_cta_corrientes y
               where y.nro_cuenta = p_nro_cuenta;      
              end if;
          elsif v_cod_pro_encurso = 11 then --En Cierre--
              v_lugar := 'Calculo de Saldo Cta.Cte-Cierre';      
              select nvl(SAL_TOTAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0),
                     nvl(SAL_RETENIDO,0), nvl(SAL_BLOQUEADO,0)
                into v_sal_total, v_sal_retenido, v_sal_bloqueado
                from cc_cta_corrientes y
               where y.nro_cuenta = p_nro_cuenta;
          else
            v_tie_error := 'S';
            v_men_error := 'Error. No se puede determinar el proceso en curso';
            --raise_application_error(-20000, 'Error. No se puede determinar el proceso en curso');
          end if;
       elsif v_cod_modulo = 3 then
          if v_cod_pro_encurso = 10 then --Inicio--
              v_lugar := 'Calculo de Saldo Aho.Vista-Inicio';
              v_ind_pendientes := 'N';
              --Si tiene mov pendientes a actualizar ingresa el cursor--
              for aho in c_cta_vistas loop
                    v_ind_pendientes := 'S';
                    SELECT (nvl(aho.sal_total, 0) - nvl(b.mto_deb_pendientes, 0) +
                            nvl(b.mto_cre_a_confirmar, 0) + nvl(b.mto_cre_pendientes, 0)), 
                            (nvl(aho.sal_retenido, 0) + nvl(b.mto_cre_a_confirmar, 0)),
                            nvl(aho.sal_bloqueado, 0)
                      into v_sal_total, v_sal_retenido, v_sal_bloqueado
                      FROM ah_cta_vistas_noc b
                     WHERE b.nro_cuenta = aho.nro_cuenta;
              end loop;
              --Si no ingreso a cursor de mov pendientes, utiliza calculo normal--
              if v_ind_pendientes = 'N' then
                 select nvl(SAL_TOTAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0),
                     nvl(SAL_RETENIDO,0), nvl(SAL_BLOQUEADO,0)
                into v_sal_total, v_sal_retenido, v_sal_bloqueado
                from ah_cta_vistas y
               where y.nro_cuenta = p_nro_cuenta;          
              end if;
          elsif v_cod_pro_encurso = 11 then --En Cierre-- 
              v_lugar := 'Calculo de Saldo Aho.Vista-Cierre';       
              select nvl(SAL_TOTAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0),
                     nvl(SAL_RETENIDO,0), nvl(SAL_BLOQUEADO,0)
                into v_sal_total, v_sal_retenido, v_sal_bloqueado
                from ah_cta_vistas y
               where y.nro_cuenta = p_nro_cuenta;
          else
            v_tie_error := 'S';
            v_men_error := 'Error. No se puede determinar el proceso en curso';
            --raise_application_error(-20000, 'Error. No se puede determinar el proceso en curso');
          end if;
       else
          v_tie_error := 'S';
          v_men_error := 'Error. No se devuelve saldo para este modulo-'||v_cod_modulo;
          --raise_application_error(-20000, 'Error. No se devuelve saldo para este modulo-'||v_cod_modulo);
       end if;
   end if;
   
   P_TIE_ERROR := V_TIE_ERROR;
   P_MEN_ERROR := V_MEN_ERROR;
   
   IF v_tie_error = 'S' then
     PR_CER_VARIABLES;
   else     
     V_SAL_DISPONIBLE := NVL(V_SAL_TOTAL,0) - NVL(V_SAL_RETENIDO,0) - NVL(V_SAL_BLOQUEADO,0);
     P_SAL_DISPONIBLE := NVL(V_SAL_DISPONIBLE,0);
     P_SAL_TOTAL := NVL(V_SAL_TOTAL,0);
     P_SAL_RETENIDO := NVL(V_SAL_RETENIDO,0);
     P_SAL_BLOQUEADO := NVL(V_SAL_BLOQUEADO,0);
   end if;  
   
EXCEPTION
   WHEN OTHERS THEN
      v_tie_error := 'S';
      v_men_error := 'Error. '||v_lugar || ' ' || SQLERRM;
      PR_CER_VARIABLES;
      P_TIE_ERROR := V_TIE_ERROR;
      P_MEN_ERROR := V_MEN_ERROR;
      --raise_application_error(-20000, v_lugar || ' ' || SQLERRM);
END;
/

