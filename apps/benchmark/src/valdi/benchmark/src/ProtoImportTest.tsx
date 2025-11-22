import { NavigationPage } from 'valdi_navigation/src/NavigationPage';
import { NavigationPageStatefulComponent } from 'valdi_navigation/src/NavigationPageComponent';
import { Style } from 'valdi_core/src/Style';
import { Label } from 'valdi_tsx/src/NativeTemplateElements';
import { systemFont } from 'valdi_core/src/SystemFont';
import { now } from './cpp';

import { load } from 'valdi_protobuf/src/ProtobufBuilder';

export function runProtoImport(): number {
  const start = now();
  load('benchmark/src/proto.protodecl');
  const end = now();
  return end - start;
}

export interface ViewModel {}
export interface ComponentContext {}

interface State {
  importLatency: number;
}

@NavigationPage(module)
export class ProtoImportTest extends NavigationPageStatefulComponent<ViewModel, ComponentContext> {
  state: State = {
    importLatency: 0,
  };

  onCreate() {
    const importLatency = runProtoImport();
    this.setState({ importLatency: importLatency });
  }

  onRender(): void {
    <view backgroundColor="white" flexDirection="column">
      <label marginTop={20} style={styles.text} value="1000 messages and 200 enums imported in"></label>
      <label style={styles.text} value={`${this.state.importLatency.toFixed(2)} ms`} />
    </view>;
  }
}

const styles = {
  text: new Style<Label>({
    font: systemFont(12),
  }),
};
