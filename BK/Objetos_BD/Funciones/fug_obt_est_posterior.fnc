CREATE OR REPLACE FUNCTION IT.FUG_obt_est_posterior (p_cod_canal ge_sol_est_posteriores.cod_canal%type,
                                p_cod_campana ge_sol_est_posteriores.cod_campana%type,
                                p_cod_modulo ge_sol_est_posteriores.cod_modulo%type,
                                p_cod_modalidad ge_sol_est_posteriores.cod_modalidad%type,
                                p_cod_est_actual ge_sol_est_posteriores.cod_est_actual%type)

                                 RETURN varchar2 IS
  v_est_posterior ge_sol_est_posteriores.cod_estado%type;
  v_cod_tip_canal ge_canales.cod_tip_canal%type;
BEGIN
  If p_cod_canal is not null then
     Select cod_tip_canal
       into v_cod_tip_canal
       from ge_canales
      where cod_canal = p_cod_canal;
  End If;

  Select cod_estado
    into v_est_posterior
    from ge_sol_est_posteriores e
   where ((nvl(e.cod_tip_canal, v_cod_tip_canal) = v_cod_tip_canal and e.cod_tip_canal is not null) or
           e.cod_tip_canal is null)
     and ((nvl(e.cod_canal, p_cod_canal) = p_cod_canal and e.cod_canal is not null) or
          e.cod_canal is null)
     and ((nvl(e.cod_campana, p_cod_campana) = p_cod_campana and e.cod_campana is not null) or
          e.cod_campana is null)
     and nvl(e.cod_modulo, p_cod_modulo) = p_cod_modulo
     and nvl(e.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
     and e.cod_est_actual = p_cod_est_actual;
  Return v_est_posterior;
Exception
	When NO_DATA_FOUND Then
	     v_est_posterior := null;
	     Return v_est_posterior;
END;
/

