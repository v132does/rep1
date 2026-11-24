create or replace procedure it.prg_cal_niv_cruzamiento is
  v_can_pro_entidad number(3) := 0;
  v_can_pro_cliente number(3) := 0;
  v_niv_cruzamiento ge_clientes.niv_cruzamiento%type;
  v_cod_persona     ge_clientes.cod_persona%type;

  -- Para recorrer todos los clientes con cuentas como principal.
  Cursor c is
      Select cod_persona, cl.niv_cruzamiento, rowid registro
        from ge_clientes cl
       where exists (Select '1'
                       from ge_cta_clientes cc
                      where cc.cod_persona = cl.cod_persona
                        and cc.relacion = 'P');
  --
  procedure lp_obt_can_pro_entidad is
  -- Obtiene la cantidad de productos que tiene la entidad
  begin
     Select count(*)
       into v_can_pro_entidad
       from ge_gru_cruzamientos;
  end lp_obt_can_pro_entidad;
  procedure lp_obt_can_pro_cliente is
  -- Obtiene la cantidad de productos que tiene el cliente
  -- De acuerdo a los grupos de cruzamiento
  begin
     Select count(distinct cod_gru_cruzamiento)
       into v_can_pro_cliente
       from ge_modalidades mo, ge_est_cuentas ec,
            ge_cuentas cu, ge_cta_clientes cc
      where mo.cod_modulo = cu.cod_modulo
        and mo.cod_modalidad = cu.cod_modalidad
        and mo.cod_gru_cruzamiento is not null
        and ec.cod_modulo = cu.cod_modulo
        and ec.cod_modalidad = cu.cod_modalidad
        and ec.estado = cu.estado
        and nvl(ec.activo, 'N') = 'S'
        and cu.nro_cuenta = cc.nro_cuenta
        and cc.relacion = 'P'
        and cc.cod_persona = v_cod_persona;
  end lp_obt_can_pro_cliente;
  procedure lp_cera_niv_cruzamiento is
  -- Cera todos los niveles de cruzamiento
  -- De los clientes que no va a procesar
  begin
     Update ge_clientes cl
        set niv_cruzamiento = 0
      where not exists (Select '1'
                          from ge_cta_clientes cc
                         where cc.cod_persona = cl.cod_persona
                           and cc.relacion = 'P')
        and nvl(cl.niv_cruzamiento,-1) != 0;
  end lp_cera_niv_cruzamiento;

begin
  v_can_pro_entidad := 0;
  -- Obtiene la cantidad de productos que tiene la entidad
  lp_obt_can_pro_entidad;
  if v_can_pro_entidad = 0 Then
     RAISE_APPLICATION_ERROR(-20001,'ERROR: No estan definidos los grupos de cruzamiento...');
  end if;
  -- Este proceso calcula el nivel de cruzamiento de todos los clientes...
  For r_clte in c Loop
      v_cod_persona     := r_clte.cod_persona;
      v_can_pro_cliente := 0;
      -- Obtiene la cantidad de productos que posee el cliente
      lp_obt_can_pro_cliente;
      v_niv_cruzamiento := v_can_pro_cliente / v_can_pro_entidad * 100;
      -- Actualiza el nivel de cruzamiento del cliente.
      if nvl(r_clte.niv_cruzamiento, -1) != nvl(v_niv_cruzamiento, -1) then
          UPDATE ge_clientes
             set niv_cruzamiento = v_niv_cruzamiento
           where rowid = r_clte.registro;
      End If;
  End Loop;
  -- Cera los niveles de cruzamiento de los clientes que no proceso...
  lp_cera_niv_cruzamiento;
exception
  when OTHERS Then
       RAISE_APPLICATION_ERROR(-20000,' Persona: '||v_cod_persona||'-'||SQLERRM);
end prg_cal_niv_cruzamiento;
/

