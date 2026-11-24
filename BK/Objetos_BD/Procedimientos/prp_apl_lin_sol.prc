create or replace procedure it.prp_apl_lin_sol(p_nro_linea in number) is
  v_nro_cuenta pv_operaciones_det.nro_cuenta%type;
  v_nro_sec_padre pv_operaciones_det.nro_sec_padre%type;
  v_sal_interes pr_cta_prestamos.mto_capital%type;
  Cursor c1 is Select nro_linea, nro_cuenta, cod_moneda, mto_aplicado, nro_sec_padre
                 from pr_lin_aplicaciones
                where nro_linea = p_nro_linea;
  Cursor c2 is Select nro_linea, nro_sec_padre, cod_persona, cod_modalidad,
                      cod_modulo, nro_cuenta, cod_mon_apl cod_moneda, monto,
                      fec_inicio, estado, tipo_gar, saldo, cod_garantia,
                      mto_aplicado
                 from pv_operaciones_det
                where nro_cuenta = v_nro_cuenta
                  and nro_sec_padre = v_nro_sec_padre;
  v_cod_mon_linea varchar2(3);
  v_cantidad      number(5);
  v_sal_garantia  number(18,2) := 0;
  v_sal_operacion number(18,2) := 0;
  v_sal_linea     number(18,2) := 0;
  v_cod_modalidad2 pr_solicitudes.cod_modalidad%type;
  v_cod_sub_modalidad pr_solicitudes.cod_sub_modalidad%type;
begin
 bEGIN
  Select cod_moneda into v_cod_mon_linea
    from pr_lineas
   where nro_linea = p_nro_linea;
 eXCEPTION
   WHEN NO_DATA_FOUND THEN
        NULL;
 eND;
  --
  update pr_lineas
     set mto_aplicado = 0
   where nro_linea = p_nro_linea;
  --
  update pr_lin_tip_garantias
     set mto_aplicado = 0
   where nro_linea = p_nro_linea;
  --
  update pr_lin_tip_gar_mad
     set mto_aplicado = 0
   where nro_linea = p_nro_linea;
  --
  --dbms_mview.refresh('PV_OP_LIM_CREDITO');
  For r1 in c1 Loop
    v_nro_cuenta := r1.nro_cuenta;
    v_nro_sec_padre := r1.nro_sec_padre;
    For r2 in c2 Loop
      begin
        select t.mto_aplicado
          into v_sal_interes 
          from it.PV_OP_LIM_CREDITO  t 
         where t.nro_cuenta=r2.nro_cuenta
           and t.cod_garantia = r2.cod_garantia;
      exception
         when too_many_rows then
           --NVB-274 se agrega esta excepcion debido a que los prestamos con mas de un tipo de garantia
           --asociado devuelve más de un registro, y como el monto aplicado es el mismo en dichos tipos
           --se filtra por rownum=1
           select t.mto_aplicado
             into v_sal_interes 
             from it.PV_OP_LIM_CREDITO  t 
            where t.nro_cuenta=r2.nro_cuenta
              and t.cod_garantia = r2.cod_garantia
              and rownum = 1;
      end;
      
      -- Actualiza modalidad
      Begin
        Select nvl(g.mto_limite, nvl(t.mto_limite,0)) - nvl(g.mto_aplicado,0)
          into v_sal_operacion
          from pr_lin_tip_garantias t, pr_lin_tip_gar_mad g
         where t.nro_linea = g.nro_linea
           and t.cod_garantia = g.cod_garantia
           and g.nro_linea = p_nro_linea
           and g.cod_modulo = r2.cod_modulo
           and nvl(g.cod_modalidad,r2.cod_modalidad) = r2.cod_modalidad
           and g.cod_garantia = r2.cod_garantia;

          If v_sal_operacion < pag_gen.fu_con_mon_a_moneda(r2.cod_moneda,
                                  v_cod_mon_linea,
                                  nvl(r2.mto_aplicado, 0 ) ) then
             --
             raise_application_error(-20000, 'Saldo de la Cuenta '||r2.nro_cuenta||' supera el del Tipo de Operacion');
          End if;
      Exception
         When NO_DATA_FOUND then
              null;
      End;
      --  SDMALICR-1
      v_cod_modalidad2 := null;
      BEGIN
         IF r2.nro_cuenta is not null AND r2.cod_modulo = 6 AND r2.cod_modalidad IN (608,645,646) THEN
            BEGIN
               SELECT cod_sub_modalidad
                 INTO v_cod_sub_modalidad
                 FROM pr_cta_prestamos
                WHERE nro_cuenta = r2.nro_cuenta;
            EXCEPTION
               WHEN no_data_found THEN
                  BEGIN
                     SELECT cod_sub_modalidad
                       INTO v_cod_sub_modalidad
                       FROM pr_solicitudes
                      WHERE nro_solicitud = to_number(replace(r2.nro_cuenta, 'Prop.Nro. ',''));
                  EXCEPTION
                     WHEN others THEN
                        v_cod_sub_modalidad := null;
                  END;
              WHEN others THEN
                v_cod_sub_modalidad := null;
            END;
            IF nvl(fug_obt_pardinamico('FAD_LIN_PCP_SUB_MAD',r2.cod_modulo, r2.cod_modalidad, null, null, v_cod_sub_modalidad),'N') = 'S' 
               AND v_cod_sub_modalidad is not null THEN
               v_cod_modalidad2 := nvl(fug_obt_pardinamico('FAD_LIN_PCP_MAD', r2.cod_modulo, r2.cod_modalidad), r2.cod_modalidad);
            ELSIF r2.cod_modalidad IN (645,646) THEN
               v_cod_modalidad2 := nvl(fug_obt_pardinamico('FAD_LIN_FOGAPY_MAD', r2.cod_modulo, r2.cod_modalidad), r2.cod_modalidad);
            END IF; 
         END IF;
      END;
      --
      Update pr_lin_tip_gar_mad
         set mto_aplicado = nvl(mto_aplicado,0) + pag_gen.fu_con_mon_a_moneda(r2.cod_moneda,
                              v_cod_mon_linea,
                              nvl(v_sal_interes, r2.mto_aplicado) )
       where nro_linea = p_nro_linea
         and cod_modulo = r2.cod_modulo
         and nvl(cod_modalidad,r2.cod_modalidad) = nvl(v_cod_modalidad2, r2.cod_modalidad)
         and cod_garantia = r2.cod_garantia;
      If sql%notfound then
         select count(*) into v_cantidad
           from pr_lin_tip_gar_mad
          where nro_linea = p_nro_linea
            and cod_garantia = r2.cod_garantia
            and cod_modulo = r2.cod_modulo;
         If nvl(v_cantidad,0) > 0 then
            raise_application_error(-20000, 'Tipo de Producto no definido para Tipo de garantia ('||fup_obt_des_tip_garantia(r2.cod_garantia)||') de la cuenta '||r2.nro_cuenta);
         Else
             select count(*) into v_cantidad
               from pr_lin_tip_gar_mad
              where nro_linea = p_nro_linea
                and cod_garantia = r2.cod_garantia;
             If nvl(v_cantidad,0) > 0 then
                raise_application_error(-20000, 'Tipo de Producto no definido para Tipo de garantia ('||fup_obt_des_tip_garantia(r2.cod_garantia)||') de la cuenta '||r2.nro_cuenta);
             End If;
         End if;

      End if;
      -- Actualiza tipo de Garantia.
      Begin
        Select nvl(mto_limite,0) - nvl(mto_aplicado,0)
          into v_sal_garantia
          from pr_lin_tip_garantias
         where nro_linea = p_nro_linea
         and cod_garantia = r2.cod_garantia;
        --
        If v_sal_garantia < pag_gen.fu_con_mon_a_moneda(r2.cod_moneda,
                                v_cod_mon_linea,
                                nvl(r2.mto_aplicado, 0 ) ) then
           --
           raise_application_error(-20000, 'Saldo de la Cuenta '||r2.nro_cuenta||' supera el del Tipo de Garantia '||fup_obt_des_tip_garantia(r2.cod_garantia));
        End if;
      Exception
         When NO_DATA_FOUND then
              null;
      End;
      --
      Update pr_lin_tip_garantias
         set mto_aplicado = nvl(mto_aplicado,0) + pag_gen.fu_con_mon_a_moneda(r2.cod_moneda,
                              v_cod_mon_linea,
                              nvl(v_sal_interes, r2.mto_aplicado ) )
       where nro_linea = p_nro_linea
         and cod_garantia = r2.cod_garantia;
      --
      If sql%notfound then
         raise_application_error(-20000, 'Tipo de garantia ('||fup_obt_des_tip_garantia(r2.cod_garantia)||') de la cuenta '||r2.nro_cuenta||' no definida');
      End if;
      --
      Begin
        Select nvl(monto,0) - nvl(mto_aplicado,0)
          into v_sal_linea
          from pr_lineas
         where nro_linea = p_nro_linea;
        --
        If v_sal_linea < pag_gen.fu_con_mon_a_moneda(r2.cod_moneda,
                                v_cod_mon_linea,
                                nvl(r2.mto_aplicado, 0 ) ) then
           --
           raise_application_error(-20000, 'Saldo de la Cuenta '||r2.nro_cuenta||' supera el de la Linea');
        End if;
      Exception
         When NO_DATA_FOUND then
              null;
      End;
      Update pr_lineas
         set mto_aplicado = nvl(mto_aplicado,0) + pag_gen.fu_con_mon_a_moneda(r2.cod_moneda,
                              v_cod_mon_linea,
                              nvl(v_sal_interes, r2.mto_aplicado ) )
       where nro_linea = p_nro_linea;
      --
      If sql%notfound then
         raise_application_error(-20000, 'No encontro registro - Linea');
      End if;
    End Loop;
  End Loop;
  --
end prp_apl_lin_sol;
/
