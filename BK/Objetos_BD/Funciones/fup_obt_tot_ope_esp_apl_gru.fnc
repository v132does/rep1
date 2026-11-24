create or replace function it.fup_obt_tot_ope_esp_apl_gru(P_COD_MONEDA        IN BA_MONEDAS.COD_MONEDA%TYPE,
                                                       P_COD_GRU_ECONOMICO IN GE_CLIENTES.COD_GRU_ECONOMICO%TYPE,
                                                       P_TIPO              IN VARCHAR2 DEFAULT 'E')
  RETURN NUMBER IS
  v_mto_esp_rie     number := 0;
  v_mto_apl_rie     number := 0;
  v_mto_retorno     number := 0;
  v_exi_lim_grupo   varchar2(1);
BEGIN
  if p_tipo = 'E' then
  ---E: Monto de Operaciones Especificas del Grupo
  ---Considerar que los límites de crédito no aprobados suman como Op. Especifica por ello solo se consideran
  ---los estados A-probado y B-loqueado.
    select sum(mto_ope_esp_linea + mto_ope_esp_sin_linea + mto_ope_apl_lin_ind)
      into v_mto_retorno
      from (
            ---Total Operaciones especificas de clientes CON límite de crédito
            select sum(nvl(fug_obt_tot_ope_esp_sol(A.COD_PERSONA, P_COD_MONEDA, a.nro_linea),0)) mto_ope_esp_linea,
	                  0 mto_ope_esp_sin_linea,
                    0 mto_ope_apl_lin_ind
              from pr_lineas a, ge_clientes b
             where a.cod_persona = b.cod_persona
               and b.cod_gru_economico = P_COD_GRU_ECONOMICO
               and a.estado in ('A','B','P')
            union all
            ---Total Operaciones especificas de clientes SIN límite de crédito o Lim. Ind. no Aplicado a Lim. Global
            select 0 mto_ope_esp_linea,
                   sum(nvl(fug_obt_tot_ope_esp_sol(b.cod_persona,P_COD_MONEDA,null),0)) mto_ope_esp_sin_linea,
                   0 mto_ope_apl_lin_ind
              from ge_clientes b
             where b.cod_gru_economico = P_COD_GRU_ECONOMICO
               and not exists (select 1
                                 from pr_lineas p
                                where p.cod_persona = b.cod_persona
                                  and p.estado in ('A','B','P'))

            union all
            ---Total Operaciones especificas de clientes CON límite de crédito
            select  0 mto_ope_esp_linea,
                    0 mto_ope_esp_sin_linea,
                    sum(nvl(pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,P_COD_MONEDA, a.mto_aplicado),0)) mto_ope_apl_lin_ind
              from pr_lineas a, ge_clientes b
             where a.cod_persona = b.cod_persona
               and b.cod_gru_economico = P_COD_GRU_ECONOMICO
               and a.estado in ('A','B')
               and exists
                      (select 1
                         from pr_gru_lin_aplicaciones gr
                        where gr.cod_persona = b.cod_persona
                          and gr.cod_gru_economico = b.cod_gru_economico
                          and nvl(gr.estado,'A') = 'N')
              );

  elsif p_tipo = 'A' then
  ---A: Monto Aplicado al limite global
    select SUM(nvl(pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, P_COD_MONEDA, nvl(a.mto_aplicado, 0)),0))  mto_aplicado
      into v_mto_retorno
      from pr_lineas a, ge_clientes b
     where a.cod_persona = b.cod_persona
       and b.cod_gru_economico = P_COD_GRU_ECONOMICO
       and a.estado in ('A','B')
       and exists (Select 1
              from pr_gru_lin_aplicaciones c
             where c.cod_persona = a.cod_persona
               and nvl(c.estado,'A') = 'A');

  elsif p_tipo = 'R' then
  ---R: Total Riesgo del Grupo
   begin
      begin
        select 'S'
          into v_exi_lim_grupo
          from pr_gru_lineas pg
         where pg.cod_gru_economico = p_cod_gru_economico
           and pg.estado in ('A', 'B', 'P');
      exception
        when no_data_found then
          v_exi_lim_grupo := 'N';
        when too_many_rows then
          v_exi_lim_grupo := 'N';
        when others then
          v_exi_lim_grupo := 'N';
      end;

     If nvl(v_exi_lim_grupo,'N') = 'N' then
       ----Cuando el grupo no tiene límite creado
       begin
         select fup_obt_tot_ope_esp_apl_gru(P_COD_MONEDA,P_COD_GRU_ECONOMICO,'E')
           into v_mto_esp_rie
           from dual;
       exception
         when no_data_found then
           v_mto_esp_rie := 0;
         when others then
           v_mto_esp_rie := 0;
       end;
      Else
        begin
          select fup_obt_tot_ope_esp_apl_gru(P_COD_MONEDA, P_COD_GRU_ECONOMICO,'E') +
                 nvl(pag_gen.FU_CON_MON_A_MONEDA(gr.cod_moneda,P_COD_MONEDA, nvl(gr.monto, 0)), 0) tot_riesgo
            into v_mto_apl_rie
            from pr_gru_lineas gr
           where gr.estado in ('A', 'B')
             and exists
                 (select 1
                    from ge_clientes b
                   where b.cod_gru_economico = gr.cod_gru_economico
                     and b.cod_gru_economico = p_cod_gru_economico);
        exception
          when no_data_found then
            begin
              select fup_obt_tot_ope_esp_apl_gru(P_COD_MONEDA,P_COD_GRU_ECONOMICO,'E') +
                     nvl(pag_gen.FU_CON_MON_A_MONEDA(gr.cod_moneda,P_COD_MONEDA,nvl(gr.monto, 0)),0) tot_riesgo
                into v_mto_apl_rie
                from pr_gru_lineas gr
               where gr.estado = 'P'
                 and exists
                     (select 1
                        from ge_clientes b
                       where b.cod_gru_economico = gr.cod_gru_economico
                         and b.cod_gru_economico = p_cod_gru_economico);
            exception
              when no_data_found then
                v_mto_retorno := 0;
              when too_many_rows then
                raise_application_error(-20000, 'Error: Más de un límite por grupo definido.'||sqlerrm);
              when Others Then
                raise_application_error(-20000, 'Error Buscando Total Riesgo de Grupos Economicos '||sqlerrm);
            end;
        end;
          v_mto_retorno := nvl(v_mto_esp_rie,0) + nvl(v_mto_apl_rie,0);
      end if;
    end;
end if;
  return nvl(v_mto_retorno,0);
EXCEPTION
  When Others Then
    raise_application_error(-20000,'Error Buscando Operaciones Especificas de Líneas de Grupos Economicos '||sqlerrm);
END;
/

