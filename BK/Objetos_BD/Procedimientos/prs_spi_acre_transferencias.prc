create or replace procedure it.prs_spi_acre_transferencias is
  g_fec_actual date := pag_cal.fu_obt_fec_actual(1);
  v_existe     varchar2(1);
  v_est_modulo  ba_modulos.estado%TYPE;
  --Procesar acreditacion automatica
  cursor transfer is
    select t.nro_referencia, t.nro_ref_externa
      from ge_snp_transferencias t, ge_spi_informes inf
     where t.fec_recepcion is not null
       and t.fec_valor <= g_fec_actual
       and t.estado = 'A'
       and t.situacion = 'R'
       and t.cod_msj_swift = 8
       and t.fecha is null
       and t.hora is null
       and t.cod_usuario is null
       and inf.Inf_Suplementaria = 'AUTH'
       and inf.cod_msj_mx = 'pacs.002'
       and ((sysdate) -t.fec_insercion)*24*60 >30--pasado ya 30 minutos de insercion( para control nada mas)
       and inf.nro_ref_msj_original = t.nro_ref_externa;


begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
  if  v_est_modulo not in  (1, 6) THEN
        for x in transfer loop
          begin
            select 'S'
              into v_existe
              from ge_snp_mensajes men
             where men.nro_ref_externa = x.nro_ref_externa
               and men.cod_msj_swift = 2
               and men.error is not null;
          exception
            when no_data_found then
              v_existe := 'N';
            when others then
              v_existe := 'N';
          end;
          if nvl(v_existe, 'N') = 'S' then
            --Actualiza a ESTADO S primeramente
            update ge_snp_transferencias
               set estado = 'S'
             where nro_referencia = x.nro_referencia;
            commit;
            update ge_snp_transferencias
               set estado = 'A', situacion = 'L'
             where nro_referencia = x.nro_referencia;
            commit;
          end if;
        end loop;
  end if;
end prs_spi_acre_transferencias;
/
