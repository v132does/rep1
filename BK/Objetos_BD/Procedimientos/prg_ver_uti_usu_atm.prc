create or replace procedure it.prg_ver_uti_usu_atm(p_ind_error out varchar2) is
  --Verificar cambiar el usuario ATM--
  --Creado por Ramon Pavon - 22/01/2015--
  v_cod_usu_atm ba_usuarios.cod_usuario%type := null;
  v_can_usu_atm_utilizado number := fug_obt_pardinamico('CAN_USU_ATM_UTILIZADO');
  v_ind_error varchar2(1) := 'N';
  v_cod_usu_atm_actual ba_usuarios.cod_usuario%type := fug_obt_pardinamico('COD_USU_ATM_ACTUAL');
  v_cod_usu_atm_control ba_usuarios.cod_usuario%type;
  v_cod_nro_atm_control number(4);
  v_fec_actual          date := pae_cnf.FU_OBT_FEC_ACTUAL(1);
  PRAGMA AUTONOMOUS_TRANSACTION;

begin
  --DYDMR-5803--Modificado por rpavon 03.01.17--
  --Agregado para re-validacion de nivel de utilizacion de usuarios ATM--
  v_cod_usu_atm_control := null;
  v_cod_nro_atm_control := null;
  
  select MIN(NVL(TO_NUMBER(SUBSTR(x.cod_usuario,4)),0))
    into v_cod_nro_atm_control
    from ba_usuarios x
   where substr(x.COD_USUARIO,1,3) = 'ATM'
     and not exists (SELECT a.cod_usuario, COUNT(DISTINCT(A.HORA))
                       FROM GE_MOVIMIENTOS A
                      WHERE substr(A.COD_USUARIO,1,3) = 'ATM'
                        and A.FECHA = v_fec_actual
                        and a.cod_usuario = x.cod_usuario
                      GROUP BY A.COD_USUARIO
                     having COUNT(DISTINCT(A.HORA)) >= 86400);
                     
  if v_cod_nro_atm_control is not null then
     select decode(v_cod_nro_atm_control,0,'ATM','ATM'||to_char(v_cod_nro_atm_control))
       into v_cod_usu_atm_controL
       from dual;
  end if;
    
  --Cambiar de usuario el parametro e inicializar el contador--
  if v_cod_usu_atm_control is not null and v_cod_usu_atm_control <> v_cod_usu_atm_actual then
     --Si hay algun usuario que no llego al limite, reutiliza--
     v_cod_usu_atm := v_cod_usu_atm_control;
  elsif v_cod_usu_atm_control is null then
     --Si no hay hora disponibles entre ya usados, trae siguiente--
     v_cod_usu_atm := fug_obt_sig_usu_atm;
  else
     null;
  end if;

  if v_cod_usu_atm is not null then
     if v_cod_usu_atm <> v_cod_usu_atm_actual then
        v_can_usu_atm_utilizado := NVL(TO_NUMBER(SUBSTR(v_cod_usu_atm,4)),0) + 1;
        prg_act_par_dinamico('COD_USU_ATM_ACTUAL',null,null,null,null,v_cod_usu_atm,null);
        prg_act_par_dinamico('CAN_USU_ATM_UTILIZADO',null,null,null,null,v_can_usu_atm_utilizado,null);
     end if;
  else
     v_ind_error := 'S';
  end if;
  commit;
  p_ind_error := v_ind_error;
exception
  when others then
     raise_application_error(-20000,'Error en prg_ver_uti_usu_atm:'||sqlerrm);
end;
/

