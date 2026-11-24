create or replace procedure it.prp_val_con_gru_lineas(p_nro_linea       in pr_lineas.nro_linea%type,
                                                   p_nro_lin_global  in pr_gru_lineas.nro_linea%type,
                                                   p_respuesta       in out number,
                                                   p_det_error       in out varchar)is

   v_existe                 varchar2(1) := 'S';
   v_respuesta              number(1)   := 0;
   v_sal_gar                number      := 0;
   v_cod_moneda             varchar2(3);
   v_cod_mon_2              varchar2(3);
   v_mto_apl                number;
   v_nro_lin_glo_obtenido   pr_gru_lineas.nro_linea%type;   
   v_est_lim_global         pr_gru_lineas.estado%type;
   v_est_lim_indiv          pr_lineas.estado%type;   
   v_val_configuracion      varchar2(1);
   v_det_error              varchar2(120);
   v_exi_garantia           varchar2(1);
   v_exi_gar_prod           varchar2(1);
   
   -- Cursor de tipos de garantía globales
   cursor tip_gar_global(p_lin_global pr_gru_lineas.nro_linea%type)is
          Select a.cod_garantia, a.mto_limite, a.mto_aplicado, b.cod_moneda, b.cotizacion,
                 nvl(a.mto_limite,0) saldo
          from pr_gru_lin_tip_garantias a, pr_gru_lineas b
          Where a.nro_linea = b.nro_linea
            and a.nro_linea = p_lin_global;

   -- Cursor de Tipo de Productos globales
   Cursor tip_pro_global (p_lin_global pr_gru_lineas.nro_linea%type,
                          p_cod_garantia in varchar2) is
          Select a.nro_linea, a.cod_garantia, a.cod_modulo, a.cod_modalidad, a.mto_limite, nvl(a.mto_aplicado,0),
                 nvl(a.mto_limite,0) saldo
          from pr_gru_lin_tip_gar_mad a
          where a.nro_linea    = p_lin_global
            and a.cod_garantia = p_cod_garantia;

      -- Cursor de tipos de garantía individuales
   cursor tip_gar_individual is
          Select a.cod_garantia, a.mto_limite, a.mto_aplicado, b.cod_moneda, b.cotizacion,
                 nvl(a.mto_limite,0) saldo
          from pr_lin_tip_garantias a, pr_lineas b
          Where a.nro_linea = b.nro_linea
            and b.nro_linea = p_nro_linea;

   -- Cursor de Tipo de Productos individuales
   Cursor tip_pro_individual (p_cod_garantia in varchar2) is
          Select a.nro_linea, a.cod_garantia, a.cod_modulo, a.cod_modalidad
          from pr_lin_tip_gar_mad a
          where a.nro_linea    = p_nro_linea
            and a.cod_garantia = p_cod_garantia;

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

----Obtener nro. linea global
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

function lf_val_aplicacion(p_lim_global      pr_gru_lin_aplicaciones.nro_linea%type,
                           p_lim_individual  pr_gru_lin_aplicaciones.nro_lin_individual%type) return varchar2 is
v_exi_aplicado      varchar2(1);
begin

  begin
    select 'S'
      into v_exi_aplicado
      from pr_gru_lin_aplicaciones r 
     where r.nro_linea = p_lim_global
       and r.nro_lin_individual = p_lim_individual ;
  exception
    when no_data_found then
      v_exi_aplicado := 'N';
    when others then
      v_exi_aplicado := 'N';
  end;

  return v_exi_aplicado;
end;


BEGIN

 v_nro_lin_glo_obtenido := lf_obt_nro_lin_global;

 If v_nro_lin_glo_obtenido != 0 Then		
      -- Desde el Limite Global hacia el Límite individual
      For i in tip_gar_global (v_nro_lin_glo_obtenido)loop --> Busco los tipos de garantías configuradas en el límite
            v_sal_gar := 0;
            Begin
                 Select distinct('S')
                   into v_existe
                   from pr_lin_tip_garantias a
                  Where a.nro_linea = p_nro_linea
                    and a.cod_garantia = i.cod_garantia;
            Exception
                 When no_data_found Then
                      v_existe := 'N';
            End;
            If v_existe = 'S' Then
              
                For x in tip_pro_global (v_nro_lin_glo_obtenido, i.cod_garantia) loop --> Busco los tipos de productos configuradas por garantías en el límite
                      If x.cod_modulo is not null Then        --> Si Tiene configurado tipo de producto, voy a bajar al nivel de detalle por tipos de productos
                         If x.cod_modalidad is not null Then  --> Si tiene detalle de productos por tipo de productos empezar a controlar desde aqui
                            Begin
                                 Select distinct('S')
                                   into v_existe
                                  from pr_lin_tip_gar_mad a
                                  where a.nro_linea     = p_nro_linea
                                    and a.cod_garantia  = x.cod_garantia
                                    and a.cod_modulo    = x.cod_modulo
                                    and a.cod_modalidad = x.cod_modalidad;
                            Exception
                                  When no_data_found Then
                                       null; ---si no encuentra configurado en el individual no pasa nada
                            End;
                            --> Controlar Saldos
                            Begin
                                Select distinct('S')
                                   into v_existe
                                  from pr_lin_tip_gar_mad a, pr_lineas b
                                  where a.nro_linea     = b.nro_linea
                                    and a.nro_linea     = p_nro_linea
                                    and a.cod_garantia  = x.cod_garantia
                                    and a.cod_modulo    = x.cod_modulo
                                    and nvl(a.cod_modalidad,x.cod_modalidad) = x.cod_modalidad
                                    and pal_cam.FU_CON_MON_A_MONEDA(b.cod_moneda,i.cod_moneda,nvl(a.mto_aplicado,0),i.cotizacion)
                                                        <= nvl(x.saldo,0);
                            Exception
                                 When no_data_found Then
                                     null;

                            End;
                         Else --> Si no tiene configurado la modalidad de todas maneras se debe controlar el monto
                            --> Controlar Saldos
                            Begin
                                Select distinct('S')
                                   into v_existe
                                  from pr_lin_tip_gar_mad a, pr_lineas b
                                  where a.nro_linea     = b.nro_linea
                                    and a.nro_linea     = p_nro_linea
                                    and a.cod_garantia  = x.cod_garantia
                                    and a.cod_modulo    = x.cod_modulo
                                    and pal_cam.FU_CON_MON_A_MONEDA(b.cod_moneda,i.cod_moneda,nvl(a.mto_aplicado,0),i.cotizacion)
                                                        > nvl(x.saldo,0);
                                --> Saldo del Límite individual por producto supera el saldo del límite global
                                v_respuesta := 5;
                                v_det_error :='Cliente: '||lf_obt_cod_persona(p_nro_linea)||'- Mod.: '||x.cod_modulo||'- Modal.: '||x.cod_modalidad||'- Garantía: '||
                                                fup_obt_des_tip_garantia(x.cod_garantia);
                                
                                goto salir;
                            Exception
                                 When no_data_found Then
                                      Begin
                                          Select distinct('S')
                                             into v_existe
                                            from pr_lin_tip_gar_mad a, pr_lineas b
                                            where a.nro_linea     = b.nro_linea
                                              and a.nro_linea     = p_nro_linea
                                              and a.cod_garantia  = x.cod_garantia
                                              and a.cod_modulo    = x.cod_modulo;
                                      Exception
                                          --> Gar. Ind. Tiene la Gar. Abierta para todos y la Global esta limitada a "X" Productos.
                                          When no_data_found Then
                                               null; --> Quiere decir que la Individual NO tiene el módulo, el caso es correcto!
                                      End;
                            End;
                         End IF;

                      Else
                          Begin
                               Select distinct('S')
                                 into v_existe
                                from pr_lin_tip_garantias a
                                where a.nro_linea     = p_nro_linea
                                  and a.cod_garantia  = x.cod_garantia;
                          Exception
                                When no_data_found Then
                                     --> Configuración por Garantía distinta al límite global.-
                                     v_respuesta := 4;
                                     v_det_error :='Cliente: '||lf_obt_cod_persona(p_nro_linea)||'- Mod.: '||x.cod_modulo||'- Modal.: '||x.cod_modalidad||'- Garantía: '||
                                                    fup_obt_des_tip_garantia(x.cod_garantia);
                                     
                                     goto salir;
                          End;
                          --> Controlar Saldos
                          Begin
                               Select distinct('S')
                                 into v_existe
                                from pr_lin_tip_garantias a, pr_lineas b
                                where a.nro_linea     = b.nro_linea
                                  and a.nro_linea     = p_nro_linea
                                  and a.cod_garantia  = x.cod_garantia
                                  and pal_cam.FU_CON_MON_A_MONEDA(b.cod_moneda,i.cod_moneda,nvl(a.mto_aplicado,0),i.cotizacion)
                                                      <= nvl(i.saldo,0);
                          Exception
                                When no_data_found Then
                                  if lf_val_aplicacion(v_nro_lin_glo_obtenido,p_nro_linea) = 'N' then    
                                     v_respuesta := 3;
                                     v_det_error :='Cliente: '||lf_obt_cod_persona(p_nro_linea)||'- Mod.: '||x.cod_modulo||'- Modal.: '||x.cod_modalidad||'- Garantía: '||
                                                    fup_obt_des_tip_garantia(x.cod_garantia);
                                     
                                     goto salir;
                                 else
                                   null;
                                 end if;
                          End;
                      End If;
                End Loop;
            End If;
            -- Si no tiene configurado algun tipo de producto quiere decir que la garantía esta habilitada para todos los tipos de productos.
            -- Se debe controlar el saldo de todas maneras.-
            --> Controlar Saldos
            Begin
                 Select nvl(i.saldo,0) - pal_cam.FU_CON_MON_A_MONEDA(b.cod_moneda,i.cod_moneda,nvl(a.mto_aplicado,0),i.cotizacion)
                   into v_sal_gar
                  from pr_lin_tip_garantias a, pr_lineas b
                  where a.nro_linea     = b.nro_linea
                    and a.nro_linea     = p_nro_linea
                    and a.cod_garantia  = i.cod_garantia;
            Exception
                  When no_data_found Then
                       null;
            End;
            ---lc 16-02-2015
            /*If v_sal_gar < 0 and lf_val_aplicacion(v_nro_lin_glo_obtenido,p_nro_linea) = 'N'  Then
               v_respuesta := 3;
               v_det_error :='Cliente: '||lf_obt_cod_persona(p_nro_linea)||'- Tip. Garantía: '|| fup_obt_des_tip_garantia(i.cod_garantia);
               goto salir;
            End If;*/
      End Loop;

      -- Desde el Limite Individual hacia el Límite Global
      If v_respuesta = 0 Then
          For i in tip_gar_individual Loop
            Begin
              Select distinct ('S')
                into v_exi_garantia
                from pr_gru_lin_tip_garantias a
               Where a.nro_linea = v_nro_lin_glo_obtenido
                 and a.cod_garantia = i.cod_garantia;
            Exception
              When no_data_found Then
                 v_exi_garantia := 'N';
                 v_respuesta := 4;
                 v_det_error := 'Cliente: '||lf_obt_cod_persona(p_nro_linea)||' - Garantía: '||fup_obt_des_tip_garantia(i.cod_garantia);                                               
                 goto salir;                
            End;
            
        If nvl(v_exi_garantia,'N') = 'S' then
              Begin
                Select distinct ('S')
                  into v_exi_gar_prod
                  from pr_gru_lin_tip_gar_mad a
                 Where a.nro_linea = v_nro_lin_glo_obtenido
                   and a.cod_garantia = i.cod_garantia;
              Exception
                When no_data_found Then
                   v_exi_gar_prod := 'N';
              End;

           If nvl(v_exi_gar_prod,'N') = 'S' then
            
              For x in tip_pro_individual (i.cod_garantia) loop --> Busco los tipos de productos configuradas por garantías en el límite
                    If x.cod_modulo is not null Then --> Si Tiene configurado tipo de producto, voy a bajar al nivel de detalle por tipos de productos
                       If x.cod_modalidad is not null Then --> Si tiene detalle de productos por tipo de productos empezar a controlar desde aqui
                          Begin
                               Select distinct('S')
                                 into v_existe
                                from pr_gru_lin_tip_gar_mad a
                                where a.nro_linea     = v_nro_lin_glo_obtenido
                                  and a.cod_garantia  = x.cod_garantia
                                  and nvl(a.cod_modulo,x.cod_modulo)       = x.cod_modulo
                                  and nvl(a.cod_modalidad,x.cod_modalidad) = x.cod_modalidad;
                          Exception
                                When no_data_found Then --> Si no encuenta posiblemente configuro la garantia para todos los productos
                                     Begin
                                         Select distinct('S')
                                           into v_existe
                                          from pr_gru_lin_tip_gar_mad a
                                          where a.nro_linea     = v_nro_lin_glo_obtenido
                                            and a.cod_garantia  = x.cod_garantia;
                                     Exception
                                          when no_data_found then
                                               v_respuesta := 6;
                                               v_det_error := 'Cliente: '||lf_obt_cod_persona(p_nro_linea)||'- Mod.: '||x.cod_modulo||'- Modal.: '||x.cod_modalidad||'- Garantía: '||
                                                               fup_obt_des_tip_garantia(x.cod_garantia);                                               
                                               goto salir;
                                     End;
                          End;
                       Else --> Si es nulo quiere decir que esta habilitado para todo y debo controlar por tipo de producto
                          Begin
                               Select distinct('S')
                                 into v_existe
                                from pr_gru_lin_tip_gar_mad a
                                where a.nro_linea     = v_nro_lin_glo_obtenido
                                  and a.cod_garantia  = x.cod_garantia
                                  and a.cod_modulo    = x.cod_modulo;
                          Exception
                                When no_data_found Then
                                     v_respuesta := 6;
                                     v_det_error := 'Cliente: '||lf_obt_cod_persona(p_nro_linea)||'- Mod.: '||x.cod_modulo||'- Modal.: '||x.cod_modalidad||'- Garantía: '||
                                                     fup_obt_des_tip_garantia(x.cod_garantia);                                               
                                     goto salir;
                          End;
                       End IF;
                    End If;
               End Loop;
              End If; 
             End If; 
            End Loop;
      End If;
 End If;     
      << salir >>
      p_respuesta:= v_respuesta;
      p_det_error := v_det_error;
END prp_val_con_gru_lineas;
/

