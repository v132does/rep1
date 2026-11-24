create or replace procedure it.prg_blo_des_credito(rp_blocre in ge_cta_blo_creditos%rowtype) is
   /************************************************************/
   /*   nombre: prc_blo_des_credito                             */
   /*   fecha: 07/07/2026                                       */
   /*   objetivo: bloquear o descloquear operciones de crédito  */
   /*  a la cta. corrientes en base a un grupo de transacciones */
   /*************************************************************/
   
   v_gru_trans           ge_cta_blo_creditos.cod_gru_transaccion%type := fug_obt_pardinamico('GRU_TRANS_BLOQ_CRED');
   v_cod_blo_credito     ge_cta_blo_creditos.cod_blo_credito%type;
   v_cod_modalidad       ge_cuentas.cod_modalidad%type;
   v_tra_prohibidas      number;
   v_estado              ge_cuentas.estado%type;
   
   --cursor para el bloqueo de cuentas
   cursor c_trans_blo is 
     select t.cod_gru_transaccion, t.cod_transaccion, t.cod_modulo, t.cod_modalidad
       from ge_cuentas c,
            ge_gru_transacciones_det t
      where c.cod_modulo = t.cod_modulo
        and c.cod_modalidad = t.cod_modalidad
        and c.nro_cuenta = rp_blocre.nro_cuenta
        and t.cod_gru_transaccion = v_gru_trans;

   cursor c_trans_des is
     select b.cod_gru_transaccion, d.cod_transaccion, d.cod_modulo, d.cod_modalidad
       from ge_cuentas c,
            ge_cta_blo_creditos b,
            ge_cta_blo_creditos_det d
      where c.nro_cuenta = b.nro_cuenta
        and b.cod_blo_credito = d.cod_blo_credito
        and c.cod_modulo = d.cod_modulo
        and c.cod_modalidad = d.cod_modalidad
        and c.nro_cuenta = rp_blocre.nro_cuenta
        and b.cod_gru_transaccion = v_gru_trans
        and b.estado = 'B';        
   
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
  
  if rp_blocre.estado is not null then 
    -- BUSCA SI EXISTE UN BLOQUEO ACTIVO ('B')
    select max(cod_blo_credito)
      into v_cod_blo_credito
      from ge_cta_blo_creditos
     where nro_cuenta = rp_blocre.nro_cuenta
       and cod_gru_transaccion = v_gru_trans
       and estado = 'B';

    begin
      select cod_modalidad, c.estado 
        into v_cod_modalidad, v_estado
        from ge_cuentas c
       where c.nro_cuenta = rp_blocre.nro_cuenta
         and c.cod_modulo in (3,4) 
         and c.cod_modalidad in (31,41); --solo ctas. de AV y CC
    exception
      when no_data_found then
        raise_application_error(-20001, 'Cuenta inexistente o modalidad incorrecta.');
      when others then
        raise_application_error(-20002, 'No se pudo validar la cuenta. '||sqlerrm);   
    end;
    
    if nvl(v_estado,'C') in ('C','P') then
      raise_application_error(-20003, 'Estado de la cuenta no permite el bloqueo.');  
    end if;       
    ---------------------------------------------------------------------------
    -- BLOQUEO DE LA CUENTA
    ---------------------------------------------------------------------------
    if rp_blocre.estado = 'B' then
        -- se verifica si ya está bloqueada
        if v_cod_blo_credito is not null then
            raise_application_error(-20004, 'La cuenta ya se encuentra BLOQUEADA para este grupo de transacciones.');
        end if;

        -- Si no se tiene bloqueo activo es NULL (no hay datos activos o la tabla está vacía), avanza e inserta.
        select s_cod_blo_credito.nextval into v_cod_blo_credito from dual; -- Reemplazar por tu secuencia o lógica de ID

        begin
          insert into ge_cta_blo_creditos(cod_blo_credito,nro_cuenta,estado,observacion, 
          cod_gru_transaccion,cod_usu_bloqueo,fec_bloqueo,cod_area)
               values (v_cod_blo_credito,rp_blocre.nro_cuenta,rp_blocre.estado, rp_blocre.observacion,
          v_gru_trans,user,trunc(sysdate),rp_blocre.cod_area);
        exception
          when others then
            raise_application_error(-20005,'Error al realizar el bloqueo de crédito a la cuenta. '||sqlerrm);
        end;  
        
        for r in c_trans_blo loop  
          begin
            insert into ge_cta_blo_creditos_det(cod_blo_credito,cod_transaccion,cod_modulo,cod_modalidad)
                 values (v_cod_blo_credito,r.cod_transaccion,r.cod_modulo,r.cod_modalidad);
          exception
            when others then
              raise_application_error(-20006,'No se pudo insertar el detalle del bloqueo de crédito a la cuenta. '||sqlerrm);
          end;     
                  
          --se inserta la transacción prohibida para la cuenta
          begin
            insert into ge_tra_prohibidas(cod_transaccion,cod_modulo,cod_modalidad,nro_cuenta,observaciones)
                values (r.cod_transaccion, r.cod_modulo, r.cod_modalidad, rp_blocre.nro_cuenta, rp_blocre.observacion);
          exception
            when dup_val_on_index then
              --si ya se tiene la trans. como prohibida para la cuenta no se vuelve a insertar
              null;
            when others then
              raise_application_error(-20007,'No se pudo insertar la transacción prohibida, verifique.'||sqlerrm);
          end;    
             
        end loop;  
        
        --se indica que la cuenta tiene transacción prohibida
        if v_cod_modalidad = 41 then
          update cc_cta_corrientes c
             set c.tra_prohibida = 'S'
           where c.nro_cuenta = rp_blocre.nro_cuenta;
           
          if sql%notfound then
            raise_application_error(-20008,'No se pudo actualizar el indicador de transacción prohibida, verifique. '||sqlerrm);
          end if;   
        elsif v_cod_modalidad = 31 then          
          update ah_cta_vistas c
             set c.tra_prohibida = 'S'
           where c.nro_cuenta = rp_blocre.nro_cuenta;
           
          if sql%notfound then
            raise_application_error(-20009,'No se pudo actualizar el indicador de transacción prohibida, verifique. '||sqlerrm);
          end if;                
        end if;
    ---------------------------------------------------------------------------
    -- DESBLOQUEO DE LA CUENTA
    ---------------------------------------------------------------------------
    elsif rp_blocre.estado = 'D' then
        --Se verifica si la misma cuenta realmente está bloqueada para poder desbloquearla
        if v_cod_blo_credito is null then
            raise_application_error(-20010, 'No se puede desbloquear. La cuenta NO se encuentra bloqueada o no registra datos activos.');
        end if;
        
        for d in c_trans_des loop  
          delete from ge_tra_prohibidas p
          where p.nro_cuenta = rp_blocre.nro_cuenta
            and p.cod_transaccion = d.cod_transaccion
            and p.cod_modulo = d.cod_modulo
            and p.cod_modalidad = d.cod_modalidad;            
            
        end loop; 
        
        -- si pasó la validación, significa que encontramos el id del bloqueo activo.
        -- procedemos a actualizar ese registro específico para pasar su estado a 'D'.
        update ge_cta_blo_creditos 
           set estado = 'D',
               cod_usu_desbloqueo = user,
               fec_desbloqueo = trunc(sysdate),
               observacion = observacion||' - '||rp_blocre.observacion
         where nro_cuenta = rp_blocre.nro_cuenta
           and estado = 'B';
           
        if sql%notfound then
          raise_application_error(-20012,'No se pudo desbloquear la cuenta. '||sqlerrm);
        end if;         
        
        --se verifica si tiene otras transacciones prohibidas
        select count(1)
          into v_tra_prohibidas
          from ge_tra_prohibidas p
         where p.nro_cuenta = rp_blocre.nro_cuenta;
         
        --si no tiene otras trans. se indica que la cuenta NO tiene transacción prohibida
        if v_tra_prohibidas = 0 then
          if v_cod_modalidad = 41 then
            update cc_cta_corrientes c
               set c.tra_prohibida = 'N'
             where c.nro_cuenta = rp_blocre.nro_cuenta;
             
            if sql%notfound then
              raise_application_error(-20013,'No se pudo actualizar el indicador de transacción prohibida, verifique. '||sqlerrm);
            end if;   
          elsif v_cod_modalidad = 31 then          
            update ah_cta_vistas c
               set c.tra_prohibida = 'N'
             where c.nro_cuenta = rp_blocre.nro_cuenta;
             
            if sql%notfound then
              raise_application_error(-20014,'No se pudo actualizar el indicador de transacción prohibida, verifique. '||sqlerrm);
            end if;                
          end if;                     
        end if;
    else
        raise_application_error(-20015, 'Acción no válida. Debe ser BLOQUEAR o DESBLOQUEAR.');
    end if;   
  end if;    
end prg_blo_des_credito;
--acordate que faltan los triggers de auditoría para las tablas nuevas.
/
