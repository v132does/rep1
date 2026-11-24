create or replace procedure it.PRL_GEN_AGE_TRANSFERENCIAS
is
   -- personas a los cuales asignar las actividades, sólo las q no tienen crédito en cuenta
   cursor personas is
      select nvl(cod_per_beneficiario, FUG_OBT_PER_ENTIDAD) cod_persona, nom_beneficiario, cod_moneda, monto, nro_ref_externa,
             tel_beneficiario, dir_beneficiario, fec_recepcion, nom_solicitante,
             fue_obt_des_ciudad(cod_pai_solicitante, cod_ciu_solicitante) ciudad
        from lc_transferencias
       where nvl(estado,'PE') = 'PE'
         --and nro_cta_referencia is null -- AAP 20-06-07
				 			 											 			-- Inicialmente se entendio que solamente
				 			 											 			-- las transferencias por caja se debian
																					-- informar como agenda. Por pedido de 
																					-- JDR se modifica esto y ahora todas las
																					-- transf. de la caixa generan agenda
				and TIP_MENSAJE = 'SPRI'
         and cod_modalidad = 75;
   -- usuarios entre los cuales se distribuye
   cursor usuarios is
     select cod_usuario
       from ba_usuarios
      where gru_agenda = 4; --call center

   type vector is table of varchar2(10) index by  binary_integer;
   v_usuarios vector;
   ind number := 0;
   v_can_usuarios number;
   v_existe varchar2(1);
begin
  -- vector que tiene los usuarios entre los cuales distribuir las actividades
  for us in usuarios loop
      ind := ind + 1;
      v_usuarios(ind) := us.cod_usuario;
  end loop;
  v_can_usuarios := ind;
  -- proceso de distribución de actividades
  ind := 0;
  for pe in personas loop

      --verificar si ya existe agenda pendiente para esta transferencia
      begin
      select 'S'
        into v_existe
        from cr_agendas b
       where b.nro_referencia = pe.nro_ref_externa
         and b.cod_actividad  = 5
         and exists (Select '1'--- Solo las agendas pendientes ---
                       from cr_age_est_actividades e
                      where e.cod_actividad = b.cod_actividad
                       and e.cod_estado = b.cod_estado
                       and grupo = 'P');
      exception
         when too_many_rows then
             v_existe := 'S';
         when others then
             v_existe := 'N';
      end;
      if v_existe = 'N' then
          ind := ind + 1;
          --generar agenda
          prg_gen_age_actividades(pe.cod_persona, v_usuarios(ind), 5, 1, 1, pag_cal.FU_OBT_FEC_ACTUAL(1),
             'A nombre de: '||pe.nom_beneficiario || chr(10) ||
             'Teléfono:    '||pe.tel_beneficiario || chr(10) ||
             'Dirección:   '||pe.dir_beneficiario || chr(10) ||
             'Monto:       '||pe.monto||' '||pe.cod_moneda || chr(10) ||
             'Enviada por: '||pe.nom_solicitante ||' - '|| pe.ciudad || chr(10) ||
             'En fecha:    '||to_char(pe.fec_recepcion,'dd/mm/yyyy'),
              pe.nro_ref_externa);
          --inicializar contador
          if ind >= v_can_usuarios then
             ind := 0;
          end if;
      end if;
  end loop;
end;
/

