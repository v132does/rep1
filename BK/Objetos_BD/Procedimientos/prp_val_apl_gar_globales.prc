create or replace procedure it.prp_val_apl_gar_globales(p_nro_linea       in pr_lineas.nro_linea%type,
                                                     p_nro_lin_global  in pr_gru_lineas.nro_linea%type default null,
                                                     p_cod_garantia    in pr_gru_lin_tip_garantias.cod_garantia%type,
                                                     p_cod_modulo      in pr_gru_lin_tip_gar_mad.cod_modulo%type,
                                                     p_cod_modalidad   in pr_gru_lin_tip_gar_mad.cod_modalidad%type,
                                                     p_mto_operacion   in pr_gru_lineas.monto%type,
                                                     p_mto_adi_saldo   in pr_gru_lineas.monto%type,
                                                     p_cod_moneda      in pr_lineas.cod_moneda%type, 
                                                     p_respuesta       in out varchar2)is

   v_exi_gar_modalidad      varchar2(1) := 'N';
   v_exi_gar_modulo         varchar2(1) := 'N';
   v_exi_garantia           varchar2(1) := 'N';
   v_exi_sal_gar_producto   varchar2(1) := 'N';
   v_exi_sal_garantia       varchar2(1) := 'N';
   v_respuesta              varchar2(240)   := '00';
   v_nro_lin_glo_obtenido   pr_gru_lineas.nro_linea%type;   
   v_no_exi_gar_producto    varchar2(1) := 'N';

 
-------------Declaracion de funciones y procesos internos ----------------------
            
function lf_obt_cod_persona(p_nro_lin  pr_lineas.nro_linea%type)return number is
v_cod_persona      pr_lineas.cod_persona%type;
begin
    if p_nro_lin is not null then
      begin
        select li.cod_persona
          into v_cod_persona
          from pr_lineas li
         where li.nro_linea = p_nro_lin;
      exception
        when no_data_found then
          v_cod_persona := 0;
          return v_cod_persona;
        when others then
          v_cod_persona := 0;
          return v_cod_persona;
      end;
      return v_cod_persona;  
    end if;  
exception
  when no_data_found then
     v_cod_persona := 0;
     return v_cod_persona;
  when others then
     v_cod_persona := 0;
    return v_cod_persona;
end lf_obt_cod_persona;

----Obtener 
function lf_obt_nro_lin_global return number is
v_nro_lin_global      pr_gru_lineas.nro_linea%type;
begin
if p_nro_lin_global is not null then
 v_nro_lin_global := p_nro_lin_global;
else
  begin
    select lg.nro_linea
      into v_nro_lin_global
      from pr_gru_lineas lg, ge_clientes g, pr_lineas li
     where lg.cod_gru_economico = g.cod_gru_economico
       and li.cod_persona = g.cod_persona
       and li.nro_linea = p_nro_linea
       and lg.estado in ('A', 'B');
  exception
    when no_data_found then
      begin
        select lg.nro_linea
          into v_nro_lin_global
          from pr_gru_lineas lg, ge_clientes g, pr_lineas li
         where lg.cod_gru_economico = g.cod_gru_economico
           and li.cod_persona = g.cod_persona
           and li.nro_linea = p_nro_linea
           and lg.estado in ('P');
      exception
        when no_data_found then
          v_nro_lin_global := 0;
        when others then
          v_nro_lin_global := 0;
      end;
    when others then
      v_nro_lin_global := 0;
  end;
end if;
  return v_nro_lin_global;
end;



BEGIN

 v_nro_lin_glo_obtenido := lf_obt_nro_lin_global;

 If v_nro_lin_glo_obtenido != 0 Then		
      --- Desde la Operación hacia el Límite Global
      --- Primero verificar si existe configuración para Garantía por Producto
           Begin
                Select distinct ('S')
                  into v_exi_gar_modalidad
                  from pr_gru_lin_tip_gar_mad a
                 where a.nro_linea = v_nro_lin_glo_obtenido
                   and a.cod_garantia = p_cod_garantia
                   and nvl(a.cod_modulo,  p_cod_modulo) =  p_cod_modulo
                   and nvl(a.cod_modalidad,  p_cod_modalidad) = p_cod_modalidad;
              Exception
                When no_data_found Then
                    --> Si no encuenta posiblemente configuro la garantia para todos los productos
                    Begin
                      Select distinct ('S')
                        into v_exi_gar_modulo
                        from pr_gru_lin_tip_gar_mad a
                       where a.nro_linea = v_nro_lin_glo_obtenido
                         and a.cod_garantia =  p_cod_garantia
                         and nvl(a.cod_modulo,  p_cod_modulo) =  p_cod_modulo;
                    Exception
                      when no_data_found then
                          Begin
                            Select distinct ('S')
                              into v_no_exi_gar_producto
                              from pr_gru_lin_tip_gar_mad a
                             where a.nro_linea = v_nro_lin_glo_obtenido
                               and a.cod_garantia = p_cod_garantia
                               and nvl(a.cod_modulo, p_cod_modulo) != p_cod_modulo;
                          Exception
                            when no_data_found then
                              null; ---Si no tiene configurado ningún otro producto(modulo/modalidad) no se debe controlar nada
                            when others then 
                              null;
                          End;
                      when others then
                          null;    
                    End;
              When others then
                 null;                  
              End;
      
      If nvl(v_no_exi_gar_producto,'N') = 'S' then
             v_respuesta := 'No Existe Garantía por Prod. Lím. Global - Garantía : '
                              ||v_nro_lin_glo_obtenido
                              ||'- Garantía: ' || fup_obt_des_tip_garantia(p_cod_garantia)
                              ||'- Modal.: ' ||p_cod_modalidad;    
               goto salir;
      End if;
      
      If v_exi_gar_modalidad = 'S' and v_exi_gar_modulo  = 'N' then
           Begin
             Select distinct ('S')
               into v_exi_sal_gar_producto
               from pr_gru_lin_tip_gar_mad a, pr_gru_lineas r
              where a.nro_linea = r.nro_linea
                and a.nro_linea = v_nro_lin_glo_obtenido
                and a.cod_garantia = p_cod_garantia
                and nvl(a.cod_modulo, p_cod_modulo) = p_cod_modulo
                and nvl(a.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
                and (a.mto_limite - a.mto_aplicado + p_mto_adi_saldo) 
                     >=  pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,r.cod_moneda,nvl(p_mto_operacion,0),null);                
           Exception
             When no_data_found Then
               v_respuesta := 'Monto supera saldo de Garantía por Prod. Lím. Global - Garantía : '
                              ||'- Límite: ' ||v_nro_lin_glo_obtenido
                              ||'- Garantía: ' || fup_obt_des_tip_garantia(p_cod_garantia)
                              ||'- Modal.: ' ||p_cod_modalidad;    
               goto salir;
           End;
      Elsif v_exi_gar_modulo  = 'S' and v_exi_gar_modalidad  = 'N' then
           Begin
             Select distinct ('S')
               into v_exi_sal_gar_producto
               from pr_gru_lin_tip_gar_mad a, pr_gru_lineas r
              where a.nro_linea = r.nro_linea
                and a.nro_linea = v_nro_lin_glo_obtenido
                and a.cod_garantia = p_cod_garantia
                and nvl(a.cod_modulo, p_cod_modulo) = p_cod_modulo
                and (a.mto_limite - a.mto_aplicado + p_mto_adi_saldo) 
                     >= pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,r.cod_moneda,nvl(p_mto_operacion,0),null);                
           Exception
             When no_data_found Then
               v_respuesta := 'Monto supera saldo de Garantía por Prod. Lím. Global - Garantía: '
                              ||v_nro_lin_glo_obtenido
                              ||'- Garantía: ' || fup_obt_des_tip_garantia(p_cod_garantia)
                              || '- Modal.: ' ||p_cod_modalidad;                              
               goto salir;
           End;
      End if;
      
      
      --- Desde la Operación hacia el Límite Global
      --- Segundo paso: verificar si existe configuración para Garantía 
           Begin
                Select distinct ('S')
                  into v_exi_garantia
                  from pr_gru_lin_tip_garantias a
                 where a.nro_linea = v_nro_lin_glo_obtenido
                   and a.cod_garantia = p_cod_garantia;
              Exception
                When no_data_found Then
                  v_respuesta := 'No existe Garantía : ' || fup_obt_des_tip_garantia(p_cod_garantia)
                                 ||'Configurado para Límite Global: '||v_nro_lin_glo_obtenido;
                   goto salir;
               When others then
                  v_respuesta := 'Error al obtener datos de Garantía : ' || fup_obt_des_tip_garantia(p_cod_garantia)
                                 ||'Configurado para Límite Global: '||v_nro_lin_glo_obtenido;
                  goto salir;
              End;
      
      If v_exi_garantia = 'S' then
           Begin
             Select distinct ('S')
               into v_exi_sal_garantia
               from pr_gru_lin_tip_garantias a, pr_gru_lineas r
              where a.nro_linea = r.nro_linea
                and a.nro_linea = v_nro_lin_glo_obtenido
                and a.cod_garantia = p_cod_garantia
                and (a.mto_limite - a.mto_aplicado + p_mto_adi_saldo) 
                     >= pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,r.cod_moneda,nvl(p_mto_operacion,0),null);                
           Exception
             When no_data_found Then
               v_respuesta := 'Monto supera saldo de Garantía del Lím. Global: '||v_nro_lin_glo_obtenido
                              ||'- Garantía: ' || fup_obt_des_tip_garantia(p_cod_garantia);
               goto salir;
           End;
     
      End if;      
      
 End If;     
      << salir >>
      p_respuesta:= v_respuesta;
END prp_val_apl_gar_globales;
/

